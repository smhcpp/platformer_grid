const std = @import("std");
const print = std.debug.print;
const BVH = @import("bvh.zig").BVH;
const bvh_ = @import("bvh.zig");
const mach = @import("mach");
const gpu = mach.gpu;
pub const Vec2 = @Vector(2, f32);

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
        return rect.pos + rect.size / Vec2{2, 2};
    }
};

pub const Globals = extern struct {
    aspect_ratio: f32,
    padding: f32 = 0.0,
    padding2: f32 = 0.0,
    padding3: f32 = 0.0,
};

pub const RectGPU = extern struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub const Player = struct {
    shape: Rect,
    velocity: Vec2,
    vision_radius:f32=0.4,
};

pub const Platform = struct {
    pub const Color: gpu.Color = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 };
    aabb: Rect,
};

pub const MapArea = struct {
    pub const PlatNum = 4;
    plats_bvh: *BVH=undefined,
    // this array is going to be replaced with
    // a bvh structure!
    plats: [PlatNum]Platform = undefined,
    pub fn init(allocator: std.mem.Allocator) !*MapArea {
        const m = try allocator.create(MapArea);
        m.* = .{};
        try m.setup(allocator);
        return m;
    }

    pub fn deinit(map: *MapArea, allocator: std.mem.Allocator) void {
        // allocator.free(map.platforms);
        allocator.destroy(map);
    }

    fn setup(map: *MapArea, allocator: std.mem.Allocator) !void {
        map.plats_bvh = try BVH.init(allocator);
        map.plats[0] = .{
            .aabb = .{ .pos = .{ -0.5, 0.5 }, .size = .{ 0.3, 0.2 } },
        };
        map.plats[1] = .{
            .aabb = .{ .pos = .{ 0, -0.5 }, .size = .{ 0.3, 0.2 } },
        };
        map.plats[2] = .{
            .aabb = .{ .pos = .{ 0, 0.3 }, .size = .{ 0.4, 0.1 } },
        };
        map.plats[3] = .{
            .aabb = .{ .pos = .{ 0.5, -0.3 }, .size = .{ 0.1, 0.2 } },
        };
        for (map.plats) |plat| {
            try map.plats_bvh.insert(plat);
        }
        // map.plats_bvh.printBVH();
    }
};
