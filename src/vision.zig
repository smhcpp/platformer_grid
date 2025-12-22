const std = @import("std");
const BVH = @import("bvh.zig").BVH;
const T = @import("types.zig");
const print = std.debug.print;

pub const Vision = struct {
    origin: T.Vec2,
    pub fn init(allocator: std.mem.Allocator, origin: T.Vec2) !*Vision {
        _ = allocator;
        return Vision{
            .origin = origin,
        };
    }

    pub fn castSingleRay(v: *Vision, bvh: *const BVH) ?T.HitPoint {
        const col = bvh.castRay(v.origin, T.Vec2{ 1, 0 });
        return col;
    }

    pub fn deinit(v: *Vision) void {
        _ = v;
        // v.allocator.destroy(v);
    }
};
