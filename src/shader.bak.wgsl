struct VertexInfo {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

struct Rect {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
}

struct Globals {
    aspect_ratio: f32,
    // Note: Implicit padding to 16 bytes happens here in WGSL
}

@group(0) @binding(0) var<uniform> rect: Rect;
@group(0) @binding(1) var<uniform> globals: Globals;

@vertex fn vertex_main(@builtin(vertex_index) vindex : u32) -> VertexInfo {
    let x = rect.x;
    let y = rect.y;
    let w = rect.w;
    let h = rect.h;
    var pos_world = array<vec2<f32>, 6>(
        vec2<f32>(x, y),
        vec2<f32>(x, y + h),
        vec2<f32>(x + w, y),
        vec2<f32>(x + w, y),
        vec2<f32>(x, y + h),
        vec2<f32>(x + w, y + h),
    );
    var current_pos = pos_world[vindex];
    var vertex_info: VertexInfo;
    vertex_info.pos = vec4<f32>(
        current_pos.x / globals.aspect_ratio,
        current_pos.y,
        0.0,
        1.0
    );
    vertex_info.uv = current_pos;
    return vertex_info;
}

@fragment fn frag_main(@location(0) uv: vec2<f32>) -> @location(0) vec4<f32> {
    let radius = rect.w / 2.0;
    let center_x = rect.x + radius;
    let spine_bot = rect.y + radius;
    let spine_top = rect.y + rect.h - radius;
    let clamped_y = clamp(uv.y, spine_bot, spine_top);
    let closest = vec2<f32>(center_x, clamped_y);
    let dist = distance(uv, closest);
    if (dist > radius) {
        discard;
    }
    return vec4<f32>(0.0, 0.0, 1.0, 1.0);
}
