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

@vertex fn getVertexLocation(@builtin(vertex_index) vindex: u32) -> vec4<f32> {
    // Create a quad (two triangles) centered at player position
    // Vertices: top-left, top-right, bottom-left, bottom-right
    var vertices = array<vec2<f32>, 4>(
        vec2<f32>(player_shape.pos[0],  player_shape.pos[1]),  // top-left
        vec2<f32>( player_shape.pos[0] + player_shape.size[0],  player_shape.pos[1]),  // top-right
        vec2<f32>(player_shape.pos[0],  player_shape.pos[1] + player_shape.size[1]),  // bottom-left
        vec2<f32>(player_shape.pos[0] + player_shape.size[0],  player_shape.pos[1] + player_shape.size[1]),  // bottom-right
    );
    return vec4<f32>(vertices[vindex], 0.0, 1.0);
}

@fragment fn getFragmentColor(@location(0) loc: vec2<f32>) -> @location(0) vec4<f32> {
    // Calculate distance from center of quad
    let r = player_shape.size[0] / 2.0;
    var closest = vec2<f32>(0,0);
    closest[1] = clamp(loc.y,player_shape.pos[1],player_shape.pos[1] + player_shape.size[1]);
    closest[0] = player_shape.pos[0] + r;
    let delta = loc-closest;
    let dist = length(delta);

    // Discard pixels outside circle (distance > 1.0)
    if (dist > 1.0) {
        discard;
    }

    // Optional: smooth edge (anti-aliasing)
    // let edge_smoothness = 0.05;
    // let alpha = 1.0 - smoothstep(1.0 - edge_smoothness, 1.0, dist);

    // Player color (red with smooth edges)
    return vec4<f32>(0.0, 0.0, 1.0, 1.0);
}
