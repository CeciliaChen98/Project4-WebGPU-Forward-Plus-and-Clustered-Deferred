@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lights: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusters: ClusterSet;

fn view_space(px : f32, py : f32, view_z : f32) -> vec3f {
    let ndc_x = (px / camera.screenSize.x) * 2.0 - 1.0;
    let ndc_y = (py / camera.screenSize.y) * 2.0 - 1.0;

    var view = camera.invProjMat * vec4f(ndc_x, ndc_y, -1.0, 1.0);
    view /= view.w;

    let z_target = -view_z;
    return view.xyz * z_target / view.z;
}

@compute
@workgroup_size(16, 9, 1)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {

    let x = globalIdx.x;
    let y = globalIdx.y;
    let z = globalIdx.z;

    if (x >= CLUSTER_X || y >= CLUSTER_Y || z >= CLUSTER_Z) {
        return;
    }

    // linear cluster index used for storage
    let idx = x + y * CLUSTER_X + z * (CLUSTER_X * CLUSTER_Y);

    // ------------------------------------
    // Calculating cluster bounds:
    // ------------------------------------
    // For each cluster (X, Y, Z):
    //     - Calculate the screen-space bounds for this cluster in 2D (XY).
    //     - Calculate the depth bounds for this cluster in Z (near and far planes).
    //     - Convert these screen and depth bounds into view-space coordinates.
    //     - Store the computed bounding box (AABB) for the cluster.

    let tileW = f32(camera.screenSize.x) / f32(CLUSTER_X);
    let tileH = f32(camera.screenSize.y) / f32(CLUSTER_Y);

    let x0 = f32(x) * tileW;
    let x1 = f32(x + 1u) * tileW;
    let y0 = f32(y) * tileH;
    let y1 = f32(y + 1u) * tileH;

    let invZ = 1.0 / f32(CLUSTER_Z);
    let t0 = f32(z) * invZ;
    let t1 = f32(z + 1u) * invZ;
    let depthRange = camera.zFar - camera.zNear;
    let z0 = camera.zNear + depthRange * pow(t0, 2.0);
    let z1 = min(camera.zFar, camera.zNear + depthRange * pow(t1, 2.0));

    let p00n = view_space(x0, y0, z0);
    let p10n = view_space(x1, y0, z0);
    let p01n = view_space(x0, y1, z0);
    let p11n = view_space(x1, y1, z0);

    let p00f = view_space(x0, y0, z1);
    let p10f = view_space(x1, y0, z1);
    let p01f = view_space(x0, y1, z1);
    let p11f = view_space(x1, y1, z1);

    var bmin = min(min(min(p00n, p10n), min(p01n, p11n)),
                   min(min(p00f, p10f), min(p01f, p11f)));
    var bmax = max(max(max(p00n, p10n), max(p01n, p11n)),
                   max(max(p00f, p10f), max(p01f, p11f)));

    // ------------------------------------
    // Assigning lights to clusters:
    // ------------------------------------
    // For each cluster:
    //     - Initialize a counter for the number of lights in this cluster.

    //     For each light:
    //         - Check if the light intersects with the cluster’s bounding box (AABB).
    //         - If it does, add the light to the cluster's light list.
    //         - Stop adding lights if the maximum number of lights is reached.

    //     - Store the number of lights assigned to this cluster.
    var count : u32 = 0u;
    for (var i = 0u; i < lights.numLights; i++) {
        if (count >= MAX_LIGHTS_PER_CLUSTER) { break; }
        let L = lights.lights[i];
        let lightPos : vec3f = (camera.viewMat * vec4f(L.pos, 1.0)).xyz;
        if (intersects_aabb(lightPos, bmin, bmax)) {
            clusters.clusters[idx].lights[count] = i;
            count = count + 1u;
        }
    }
    clusters.clusters[idx].numLights = count;
}
