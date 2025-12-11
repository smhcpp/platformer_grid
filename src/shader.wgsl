struct VertexInfo{
    @builtin(position) pos :vec4<f32>,
    @location(0) vertex_index :f32,
}

struct Player{
    pos:vec2<f32>,
    r:f32,
}

pub const Vec2 = @Vector(2, f32);
pub const Player = struct{
    pos:Vec2,
    radius:f32,
};

@group(0) @binding(0) var<uniform> player:Player;

@vertex fn getVertexLocation(@builtin(vertex_index) vindex : u32) -> VertexInfo {
    var pos = array<vec2<f32>, 3>(
        vec2<f32>( 0.0,  0.5),
        vec2<f32>(-0.5, -0.5),
        vec2<f32>( 0.5, -0.5)
    );
    var vertex_info:VertexInfo;
    vertex_info.pos = vec4<f32>(pos[vindex], 0.0, 1.0);
    vertex_info.vertex_index = f32(vindex);
    return vertex_info;
}
// vec4<f32>:(r, g, b, a)
@fragment fn getFragmentColor(@location(0) vertex_index: f32) -> @location(0) vec4<f32> {
    var color = vec4<f32>(vertex_index*0.3,0.0,0.2,0.3*vertex_index);
    return color;
}

// @fragment fn getFragmentColor() -> @location(0) vec4<f32> {
    // var color = vec4<f32>(0.3,0.5,0.2,1.0);
    // return color;
// }
