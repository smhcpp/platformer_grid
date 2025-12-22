const std = @import("std");
const print = std.debug.print;
const BVH = @import("bvh.zig").BVH;
const Vision = @import("vision.zig").Vision;
const bvh_ = @import("bvh.zig");
const mach = @import("mach");
const gpu = mach.gpu;
// change this vector thingie to mach.math.vec2
// it is just easier!
pub const Vec2 = @Vector(2, f32);
pub const v2Unit = Vec2{ 1, 1 };
pub const v2Zero = Vec2{ 0, 0 };
pub fn v2Scale(vec: Vec2, scale: f32) Vec2 {
    return vec * Vec2{ scale, scale };
}
pub fn distance(a: Vec2, b: Vec2) f32 {
    return @sqrt(distance2(a, b));
}
pub fn distance2(a: Vec2, b: Vec2) f32 {
    const c = a - b;
    return c[0] * c[0] + c[1] * c[1];
}

pub fn F32U(value: u32) f32 {
    return @floatFromInt(value);
}

pub fn U32F(value: f32) u32 {
    return @intFromFloat(value);
}

pub const Rect = struct {
    pos: Vec2,
    size: Vec2,
    pub fn center(rect: Rect) Vec2 {
        return rect.pos + rect.size / Vec2{ 2, 2 };
    }
};

pub const Ray = struct {
    ori: Vec2,
    dir: Vec2, // normalized direction
    dist: f32,
    pub fn pointAt(ray: *Ray, t: f32) Vec2 {
        return ray.ori + ray.dir * Vec2{ t, t };
    }
};

pub const Globals = extern struct {
    aspect_ratio: f32,
    padding: f32 = 0.0,
    padding2: f32 = 0.0,
    padding3: f32 = 0.0,
};

pub const Vec4GPU = extern struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub const Player = struct {
    vision: Vision,
    aabb: Rect,
    velocity: Vec2,
    vision_radius: f32,
};

pub const Platform = struct {
    pub const Color: gpu.Color = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 };
    aabb: Rect,
};

pub const Camera = struct {
    aabb: Rect,
    zoom: f32,
};

pub const WallBitmask = enum(u8) {
    t = 1,
    tl = 2,
    l = 4,
    bl = 8,
    b = 16,
    br = 32,
    r = 64,
    tr = 128,
};

pub const HitPoint = struct {
    pid: ?usize,
    // wall_bitmask: WallBitmask,
    dir: Vec2,
    dist: f32,
};

pub const TreeNode = struct {
    right: ?*TreeNode,
    left: ?*TreeNode,
    aabb: Rect,
    pid: ?usize,
    parent: ?*TreeNode,

    pub fn isLeaf(node: *const TreeNode) bool {
        return node.pid != null;
    }

    pub fn deinit(node: *TreeNode, allocator: std.mem.Allocator) void {
        if (node.right) |tr| tr.deinit(allocator);
        if (node.left) |bl| bl.deinit(allocator);
        allocator.destroy(node);
    }
};

pub fn getScreenLineGpu(a: Vec2, b: Vec2, camera_aabb: Rect, camera_zoom: f32, aspect_ratio: f32) Vec4GPU {
    const rel_ax = (a[0] - camera_aabb.pos[0]) * camera_zoom - aspect_ratio;
    const rel_ay = (a[1] - camera_aabb.pos[1]) * camera_zoom - 1;
    const rel_bx = (b[0] - camera_aabb.pos[0]) * camera_zoom - aspect_ratio;
    const rel_by = (b[1] - camera_aabb.pos[1]) * camera_zoom - 1;
    return Vec4GPU{
        .x = rel_ax,
        .y = rel_ay,
        .w = rel_bx,
        .z = rel_by,
    };
}

pub fn getScreenVec4GPU(aabb: Rect, camera_aabb: Rect, camera_zoom: f32, aspect_ratio: f32) Vec4GPU {
    const rel_x = (aabb.pos[0] - camera_aabb.pos[0]) * camera_zoom - aspect_ratio;
    const rel_y = (aabb.pos[1] - camera_aabb.pos[1]) * camera_zoom - 1;
    const rel_w = aabb.size[0] * camera_zoom;
    const rel_h = aabb.size[1] * camera_zoom;
    return Vec4GPU{
        .x = rel_x,
        .y = rel_y,
        .w = rel_w,
        .h = rel_h,
    };
}

pub const MapArea = struct {
    size: Vec2,
    bvh: *BVH = undefined,
    pub fn init(allocator: std.mem.Allocator) !*MapArea {
        const m = try allocator.create(MapArea);
        m.* = .{
            .size = Vec2{ 2000, 1000 },
        };
        try m.setup(allocator);
        return m;
    }

    pub fn deinit(map: *MapArea, allocator: std.mem.Allocator) void {
        map.bvh.deinit(allocator);
        allocator.destroy(map);
    }

    fn setup(map: *MapArea, allocator: std.mem.Allocator) !void {
        map.bvh = try BVH.init(allocator);
    }
};
