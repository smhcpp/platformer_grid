const std = @import("std");
pub fn F32U(value: u32) f32 {
    return @floatFromInt(value);
}
pub fn U32F(value: f32) u32 {
    return @intFromFloat(value);
}
pub const Vec2 = @Vector(2, f32);
pub const Rect = struct {
    pos: Vec2,
    size: Vec2,
};
pub const Globals = struct {
    aspect_ratio: f32,
};
pub const RectGPU = packed struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};
pub const Player = struct {
    shape: Rect,
    velocity: Vec2,
};

pub const MapArea = struct {
    platforms: []Rect = undefined,
    pub fn init(allocator: std.mem.Allocator) !*MapArea {
        const m = try allocator.create(MapArea);
        m.* = .{};
        m.setup(allocator);
        return m;
    }

    pub fn deinit(self: *MapArea, allocator: std.mem.Allocator) void {
        allocator.free(self.platforms);
        allocator.destroy(self);
    }

    fn setup(self: *MapArea, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
    }
};
