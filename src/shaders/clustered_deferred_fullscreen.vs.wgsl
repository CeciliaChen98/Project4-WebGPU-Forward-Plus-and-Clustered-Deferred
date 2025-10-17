struct VertexOutput 
{
    @builtin(position) pos : vec4f,
    @location(0) uv       : vec2f,
};    

@vertex
fn main(@builtin(vertex_index) vid : u32) -> VertexOutput {
    var positions = array<vec2f, 3>(
        vec2f(-1.0, -1.0),
        vec2f( 3.0, -1.0),
        vec2f(-1.0,  3.0)
    );

    var uvs = array<vec2f, 3>(
        vec2f(0.0, 0.0),
        vec2f(2.0, 0.0),
        vec2f(0.0, 2.0)
    );

    var out : VertexOutput;
    out.pos = vec4f(positions[vid], 0.0, 1.0);
    out.uv  = uvs[vid];
    return out;
}