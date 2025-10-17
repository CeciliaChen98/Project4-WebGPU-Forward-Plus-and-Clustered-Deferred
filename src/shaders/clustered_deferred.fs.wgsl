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
    @location(2) worldZ: f32
};


@fragment
fn main(in: VertexOutput) -> GBufferOut {

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);

    var out : GBufferOut;
    out.albedo = diffuseColor; 
    out.nor = vec4f(normalize(in.nor), 1.0); 
    out.worldZ = in.fragPos.z;
    return out;
}