@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet  : LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_gbuffer}) @binding(0) var gAlbedo  : texture_2d<f32>;
@group(${bindGroup_gbuffer}) @binding(1) var gNormal  : texture_2d<f32>;   
@group(${bindGroup_gbuffer}) @binding(2) var gWorldZ   : texture_depth_2d;  
@group(${bindGroup_gbuffer}) @binding(3) var gSampler : sampler;

struct FragmentInput
{
    @location(0) uv : vec2f
}

fn toWorldPoint(uv : vec2f, z: f32) -> vec3f {
    let ndc = uv * 2.0 - 1.0;
    let worldPos = camera.invViewMat * camera.invProjMat * vec4f(ndc, z, 1.0);
    return worldPos.xyz / worldPos.w;
}

fn cluster_coords_from_uvz(uv : vec2f, viewZPos : f32) -> vec3u {
    let x = u32(floor(uv.x * f32(CLUSTER_X)));
    let y = u32(floor(uv.y * f32(CLUSTER_Y)));

    let depthRange = camera.zFar - camera.zNear;
    let znorm = clamp((-viewZPos - camera.zNear) / depthRange, 0.0, 1.0);
    let t = pow(znorm, 1.0 / 2.0);
    let z = u32(floor(t * f32(CLUSTER_Z)));
    return vec3u(x, y, z);
}

// ------------------------------------
// Shading process:
// ------------------------------------

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let uv = vec2f(in.uv.x, 1.0 - in.uv.y);

    // --- Read G-Buffer ---
    let albedo = textureSample(gAlbedo, gSampler, uv).rgb;
    let nor = textureSample(gNormal, gSampler, uv).xyz;
    let N_world = normalize(nor);
    let z = textureSample(gWorldZ, gSampler, uv);

    let P_world = toWorldPoint(uv, z);
    let viewZ = (camera.viewMat * vec4f(P_world, 1.0)).z;

    // Determine which cluster contains the current fragment
    let indices = cluster_coords_from_uvz(uv, viewZ);
    let idx = indices.x + indices.y * CLUSTER_X + indices.z * (CLUSTER_X * CLUSTER_Y);
    let clusterPtr = &clusterSet.clusters[idx];

    // Initialize a variable to accumulate the total light contribution for the fragment.
    var totalLightContrib = vec3f(0, 0, 0);

    // For each light in the cluster:
    for (var lightIdx = 0u; lightIdx < (*clusterPtr).numLights; lightIdx++) { 
        // Access the light's properties using its index.
        let light = lightSet.lights[(*clusterPtr).lights[lightIdx]];
        totalLightContrib += calculateLightContrib(light, P_world, N_world);
    }

    // Multiply the fragment’s diffuse color by the accumulated light contribution
    var finalColor = albedo * totalLightContrib;

    // Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
    return vec4(finalColor, 1);
}