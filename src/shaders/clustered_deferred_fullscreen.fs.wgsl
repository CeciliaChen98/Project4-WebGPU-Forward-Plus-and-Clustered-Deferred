@group(${bindGroup_gbuffer}) @binding(0) var gAlbedo  : texture_2d<f32>;
@group(${bindGroup_gbuffer}) @binding(1) var gNormal  : texture_2d<f32>;   
@group(${bindGroup_gbuffer}) @binding(2) var gViewZ   : texture_2d<f32>;  
@group(${bindGroup_gbuffer}) @binding(3) var gSampler : sampler;

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet  : LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) uv : vec2f
}

fn viewPosFromUVZ(uv : vec2f, zPos : f32) -> vec3f {
    let ndc = uv * 2.0 - 1.0;
    let sx = 1.0 / camera.invProjMat[0][0];
    let sy = 1.0 / camera.invProjMat[1][1];
    let x  = ndc.x * zPos / sx;
    let y  = ndc.y * zPos / sy;
    let z  = -zPos;
    return vec3f(x, y, z);
}

// VIEW -> WORLD
fn toWorldPoint(view : vec3f) -> vec3f {
    let world = camera.invViewMat * vec4f(view, 1.0);
    return world.xyz / world.w;
}
fn toWorldDir(nor : vec3f) -> vec3f {
    let nw = camera.invViewMat * vec4f(nor, 0.0);
    return normalize(nw.xyz);
}

// Map screen uv + linear view-Z to cluster coords
fn cluster_coords_from_uvz(uv : vec2f, viewZPos : f32) -> vec3u {
    let x = u32(floor(uv.x * f32(CLUSTER_X)));
    let y = u32(floor(uv.y * f32(CLUSTER_Y)));
    let dz = (camera.zFar - camera.zNear) / f32(CLUSTER_Z);
    let z = u32(floor((viewZPos - camera.zNear) / dz));
    return vec3u(x, y, z);
}
// ------------------------------------
// Shading process:
// ------------------------------------

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let uv     = in.uv;

    // --- Read G-buffer ---
    let albedo = textureSample(gAlbedo, gSampler, uv).rgb;
    let nor    = textureSample(gNormal, gSampler, uv).rgb;
    let viewZ  = textureSample(gViewZ,  gSampler, uv).x; 

    // --- Cluster lookup ---
    let indices  = cluster_coords_from_uvz(uv, viewZ);
    let index = indices.x + indices.y * CLUSTER_X + indices.z * (CLUSTER_X * CLUSTER_Y);
    let cluster  = clusterSet.clusters[index];

    // --- Reconstruct WORLD data ---
    let P_view = viewPosFromUVZ(uv, viewZ);
    let P_world = toWorldPoint(P_view);
    let N_world = toWorldDir(nor);

    // Initialize a variable to accumulate the total light contribution for the fragment.
    var totalLightContrib = vec3f(0, 0, 0);

    // For each light in the cluster:
    for (var lightIdx = 0u; lightIdx < cluster.numLights; lightIdx++) { 
        // Access the light's properties using its index.
        let light = lightSet.lights[cluster.lights[lightIdx]];
        totalLightContrib += calculateLightContrib(light, P_world, N_world);
    }

    // Multiply the fragment’s diffuse color by the accumulated light contribution
    var finalColor = albedo * totalLightContrib;

    // Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
    return vec4(finalColor, 1);
}