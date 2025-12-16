struct Rect { x: f32, y: f32, w: f32, h: f32 }
struct Globals { aspect_ratio: f32, padding: f32, padding2:f32, padding3:f32 }

@group(0) @binding(0) var<storage, read> objects: array<Rect>;
@group(0) @binding(1) var<uniform> globals: Globals;

@vertex fn vertex_map(@builtin(vertex_index) v_idx: u32, @builtin(instance_index) i_idx: u32) -> @builtin(position) vec4<f32> {
    let r = objects[i_idx]; // Read from Platform Buffer
    let x=r.x; let y=r.y; let w=r.w; let h=r.h;
    var pos = array<vec2<f32>, 6>(
        vec2<f32>(x, y), vec2<f32>(x, y+h), vec2<f32>(x+w, y),
        vec2<f32>(x+w, y), vec2<f32>(x, y+h), vec2<f32>(x+w, y+h)
    );

    let pos = vec4<f32>(pos[v_idx].x / globals.aspect_ratio, pos[v_idx].y, 0.0, 1.0);
    return pos;
}

@fragment fn frag_map() -> @location(0) vec4<f32> {
    return vec4<f32>(0.5, 0.5, 0.5, 1.0); // Grey
}

// --- PIPELINE 2: PLAYER (Capsule) ---
struct PlayerOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) center: vec2<f32>,
    @location(2) half_size: vec2<f32>,
}

@vertex fn vertex_player(@builtin(vertex_index) v_idx: u32) -> PlayerOut {
    let r = objects[0]; // Read from Player Buffer (Always index 0)

    let x=r.x; let y=r.y; let w=r.w; let h=r.h;
    var pos = array<vec2<f32>, 6>(
        vec2<f32>(x, y), vec2<f32>(x, y+h), vec2<f32>(x+w, y),
        vec2<f32>(x+w, y), vec2<f32>(x, y+h), vec2<f32>(x+w, y+h)
    );

    var out: PlayerOut;
    out.pos = vec4<f32>(pos[v_idx].x / globals.aspect_ratio, pos[v_idx].y, 0.0, 1.0);

    // Pass Math Data
    out.uv = pos[v_idx];
    out.center = vec2<f32>(x + w*0.5, y + h*0.5);
    out.half_size = vec2<f32>(w*0.5, h*0.5);
    return out;
}

@fragment fn frag_player(in: PlayerOut) -> @location(0) vec4<f32> {
    let radius = in.half_size.x;
    let dist = distance(in.uv, in.center);
    if (dist > radius) { discard; }
    return vec4<f32>(1.0, 0.2, 0.2, 1.0); // Red
}
