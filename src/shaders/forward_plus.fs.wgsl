@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet  : LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

fn cluster_coords(worldPos: vec3f) -> vec3u {
    let clip = camera.viewProjMat * vec4f(worldPos, 1.0);
    let ndc = clip.xyz / clip.w;                  
    let uv  = 0.5 * (ndc.xy + vec2f(1.0, 1.0));   

    var x = u32(clamp(floor(uv.x * f32(CLUSTER_X)), 0.0, f32(CLUSTER_X - 1u)));
    var y = u32(clamp(floor(uv.y * f32(CLUSTER_Y)), 0.0, f32(CLUSTER_Y - 1u)));

    let view = camera.invProjMat * vec4f(ndc, 1.0);
    let viewPos = view.xyz / view.w;
    let zViewPositive = -viewPos.z;                         // view forward is -Z

    let dz = (camera.zFar - camera.zNear) / f32(CLUSTER_Z);
    var cz = u32(clamp(floor((zViewPositive - camera.zNear) / dz), 0.0, f32(CLUSTER_Z - 1u)));

    return vec3u(cx, cy, cz);
}

// ------------------------------------
// Shading process:
// ------------------------------------

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    // Determine which cluster contains the current fragment
    let indices = cluster_coords(in.pos);
    let idx = indices.x + indices.y * CLUSTER_X + indices.z * (CLUSTER_X * CLUSTER_Y);
    let cluster = clusterSet.clusters[idx];

    // Initialize a variable to accumulate the total light contribution for the fragment.
    var totalLightContrib = vec3f(0, 0, 0);

    // For each light in the cluster:
    for (var lightIdx = 0u; lightIdx < cluster.numLights; lightIdx++) { 
        // Access the light's properties using its index.
        let light = lightSet.lights[cluster.lights[lightIdx]];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    // Multiply the fragment’s diffuse color by the accumulated light contribution
    var finalColor = diffuseColor.rgb * totalLightContrib;

    // Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
    return vec4(finalColor, 1);
}