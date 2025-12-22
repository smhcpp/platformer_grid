struct Globals { aspect_ratio: f32 }
@group(0) @binding(0) var<uniform> globals: Globals;
struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) line: vec4<f32>,
}

@vertex fn vertex_main(
    @builtin(vertex_index) v_idx: u32,
    @location(0) line_data: vec4<f32>
) -> VertexOut {
    let x = line_data.x;
    let y = line_data.y;
    let w = line_data.z;
    let h = line_data.w;
    var positions = array<vec2<f32>, 2>(
        vec2<f32>(x, y),
        vec2<f32>(w, z)
    );
    return vec4<f32>(positions[v_idx].x / globals.aspect_ratio, positions[v_idx].y, 0.0, 1.0);
}

@fragment fn frag_main() -> @location(0) vec4<f32> {
    return vec4<f32>(1, 1, 0, 1);
}
