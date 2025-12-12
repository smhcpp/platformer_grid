struct VertexInfo {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

struct Player {
    pos: vec2<f32>,
    r: f32,
}

struct Globals {
    aspect: f32,
}

@group(0) @binding(1) var<uniform> globals: Globals;
@group(0) @binding(0) var<uniform> player: Player;

@vertex fn getVertexLocation(@builtin(vertex_index) vindex: u32) -> VertexInfo {
    // Create a quad (two triangles) centered at player position
    // Vertices: top-left, top-right, bottom-left, bottom-right
    var positions = array<vec2<f32>, 6>(
        vec2<f32>(-1.0,  1.0),  // top-left
        vec2<f32>( 1.0,  1.0),  // top-right
        vec2<f32>(-1.0, -1.0),  // bottom-left
        vec2<f32>( 1.0,  1.0),  // top-right
        vec2<f32>( 1.0, -1.0),  // bottom-right
        vec2<f32>(-1.0, -1.0),  // bottom-left
    );

    // UV coordinates for determining if pixel is inside circle
    var uvs = array<vec2<f32>, 6>(
        vec2<f32>(-1.0,  1.0),
        vec2<f32>( 1.0,  1.0),
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 1.0,  1.0),
        vec2<f32>( 1.0, -1.0),
        vec2<f32>(-1.0, -1.0),
    );

    var vertex_info: VertexInfo;

    // Scale by radius and translate to player position
    var scaled_pos = positions[vindex] * player.r + player.pos;
    scaled_pos.x /= globals.aspect;
    vertex_info.pos = vec4<f32>(scaled_pos, 0.0, 1.0);
    vertex_info.uv = uvs[vindex];

    return vertex_info;
}

@fragment fn getFragmentColor(@location(0) uv: vec2<f32>) -> @location(0) vec4<f32> {
    // Calculate distance from center of quad
    let dist = length(uv);

    // Discard pixels outside circle (distance > 1.0)
    if (dist > 1.0) {
        discard;
    }

    // Optional: smooth edge (anti-aliasing)
    let edge_smoothness = 0.05;
    let alpha = 1.0 - smoothstep(1.0 - edge_smoothness, 1.0, dist);

    // Player color (red with smooth edges)
    return vec4<f32>(1.0, 0.2, 0.2, alpha);
}
