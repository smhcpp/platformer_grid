struct Rect {
    x:f32,
    y:f32,
    w:f32,
    h:f32,
}
struct Globals {
    aspect_ratio:f32,
}

@group(0) @binding(0) var<uniform> rect: Rect;
@group(0) @binding(1) var<uniform> globals: Globals;
@vertex fn vertex_main(@builtin(vertex_index) VertexIndex : u32) -> @builtin(position) vec4<f32> {
    let x = rect.x / globals.aspect_ratio;
    let w = rect.w / globals.aspect_ratio;
    let y = rect.y;
    let h = rect.h;

    var pos = array<vec2<f32>, 6>(
        vec2<f32>( x, y ),
        vec2<f32>(x , y + h),
        vec2<f32>(x + w, y + h),

        vec2<f32>( x, y ),
        vec2<f32>(x + w, y + h),
        vec2<f32>(x + w, y ),
    );
    return vec4<f32>(pos[VertexIndex], 0.0, 1.0);
}

@fragment fn frag_main() -> @location(0) vec4<f32> {
    return vec4<f32>(0.0, 0.0, 1.0, 1.0);
}
