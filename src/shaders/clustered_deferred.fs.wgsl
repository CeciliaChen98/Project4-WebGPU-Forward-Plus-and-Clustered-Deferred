@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;

@group(${bindGroup_material}) @binding(0) var diffuseTex     : texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler : sampler;

struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct GBufferOut {
    @location(0) albedo : vec4f,
    @location(1) nor : vec4f,
    @location(2) viewZ: f32
};


@fragment
fn main(in: VertexOutput) -> GBufferOut {

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);

    // Compute positive linear view-Z (needs camera.viewMat)
    let viewPos = (camera.viewMat * vec4f(in.pos, 1.0)).xyz;

    var out : GBufferOut;
    out.albedo = diffuseColor; 
    out.nor = vec4f(normalize(in.nor), 1.0); 
    out.viewZ = -viewPos.z;
    return out;
}