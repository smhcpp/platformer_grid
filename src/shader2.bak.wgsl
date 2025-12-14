struct VertexInfo {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

struct Rect {
    pos: vec2<f32>,
    size: vec2<f32>,
}

struct Globals {
    aspect: f32,
}

@group(0) @binding(1) var<uniform> globals: Globals;
@group(0) @binding(0) var<uniform> player_shape: Rect;

@vertex fn getVertexLocation(@builtin(vertex_index) vindex: u32) -> VertexInfo {
    let x = player_shape.pos[0];
    let y = player_shape.pos[1];
    let w = player_shape.size[0];
    let h = player_shape.size[1];
    var vertices = array<vec2<f32>, 6>(
        vec2<f32>(x, y),         // Bottom-Left
        vec2<f32>(x + w, y),     // Bottom-Right
        vec2<f32>(x, y + h),     // Top-Left

        vec2<f32>(x + w, y),     // Bottom-Right
        vec2<f32>(x + w, y + h), // Top-Right
        vec2<f32>(x, y + h),     // Top-Left
    );
    var vertex_info: VertexInfo;
    var pos = vertices[vindex];
    // pos.x = pos.x / globals.aspect; // Uncomment to fix stretching
    vertex_info.pos = vec4<f32>(pos, 0.0, 1.0);
    vertex_info.uv = pos; // Pass raw world coordinates to fragment
    return vertex_info;
}
@fragment fn getFragmentColor(@location(0) loc: vec2<f32>) -> @location(0) vec4<f32> {
    // Just return blue for ALL pixels - no discard
    return vec4<f32>(0.0, 0.0, 1.0, 1.0);
}
// @fragment fn getFragmentColor(@location(0) loc: vec2<f32>) -> @location(0) vec4<f32> {
//     let r = player_shape.size[0] / 2.0;

//     // Adjust player_shape coordinates to match the divided vertices
//     let adjusted_pos_x = player_shape.pos[0] / globals.aspect;
//     let adjusted_size_x = player_shape.size[0] / globals.aspect;

//     var closest = vec2<f32>(0,0);
//     closest[1] = clamp(loc.y, player_shape.pos[1], player_shape.pos[1] + player_shape.size[1]);
//     closest[0] = adjusted_pos_x + adjusted_size_x / 2.0;

//     let delta = loc - closest;
//     let dist = length(delta);

//     if (dist > r / globals.aspect) {  // Adjust radius too!
//         discard;
//     }

//     return vec4<f32>(0.0, 0.0, 1.0, 1.0);
// }
