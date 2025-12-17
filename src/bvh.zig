const std = @import("std");
const T = @import("types.zig");
const Vec2 = T.Vec2;

pub const BVH = struct {
    root: ?*TreeNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*BVH {
        const bvh = try allocator.create(BVH);
        bvh.* = .{
            .root = null,
            .allocator = allocator,
        };
        return bvh;
    }

    pub fn deinit(bvh: *BVH, allocator: std.mem.Allocator) void {
        if (bvh.root) |root| {
            root.deinit(allocator);
        }
        allocator.destroy(bvh);
    }

    pub fn insert(bvh: *BVH, platform: T.Platform) !void {
        if (bvh.root) |root| {
            try bvh.insertRecursive(root, platform);
        } else {
            bvh.root = try bvh.createLeaf(platform);
        }
    }

    fn insertRecursive(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        node.aabb = getExtendedAABB(node.aabb, platform.aabb);
        if (node.data) |_| {
            const existing = node.data.?;
            node.data = null;
            const is_horizontal = node.aabb.size[0] >= node.aabb.size[1];
            try bvh.insertIntoChildren(node, existing, is_horizontal);
            try bvh.insertIntoChildren(node, platform, is_horizontal);
        } else {
            const is_horizontal = node.aabb.size[0] >= node.aabb.size[1];
            try bvh.insertIntoChildren(node, platform, is_horizontal);
        }
    }

    fn insertIntoChildren(bvh: *BVH, node: *TreeNode, platform: T.Platform, is_horizontal: bool) std.mem.Allocator.Error!void {
        const center = platform.aabb.center();
        const node_center = node.aabb.center();
        const separation_index: usize = if (is_horizontal) 0 else 1;
        const goes_tr = center[separation_index] >= node_center[separation_index];
        if (goes_tr) {
            if (node.child_tr) |tr| {
                try bvh.insertRecursive(tr, platform);
            } else {
                node.child_tr = try bvh.createLeaf(platform);
            }
        } else {
            if (node.child_bl) |bl| {
                try bvh.insertRecursive(bl, platform);
            } else {
                node.child_bl = try bvh.createLeaf(platform);
            }
        }
    }

    pub fn printBVH(bvh: *BVH) void {
        std.debug.print("BVH Tree Structure:\n", .{});
        if (bvh.root) |root| {
            printNode(root, "", true, 0, 10);
        } else {
            std.debug.print("  (empty)\n", .{});
        }
    }

    fn createLeaf(bvh: *BVH, platform: T.Platform) !*TreeNode {
        const node = try bvh.allocator.create(TreeNode);
        node.* = .{
            .child_tr = null,
            .child_bl = null,
            .aabb = platform.aabb,
            .data = platform,
        };
        return node;
    }
};

pub const TreeNode = struct {
    child_tr: ?*TreeNode,
    child_bl: ?*TreeNode,
    aabb: T.Rect,
    data: ?T.Platform,

    pub fn isLeaf(node: *const TreeNode) bool {
        return node.data != null;
    }

    pub fn deinit(node: *TreeNode, allocator: std.mem.Allocator) void {
        if (node.child_tr) |tr| tr.deinit(allocator);
        if (node.child_bl) |bl| bl.deinit(allocator);
        allocator.destroy(node);
    }
};

pub fn isAABBCollision(rect1: T.Rect, rect2: T.Rect) bool {
    const min1 = rect1.pos;
    const max1 = rect1.pos + rect1.size;
    const min2 = rect2.pos;
    const max2 = rect2.pos + rect2.size;
    return !(max1[0] < min2[0] or max1[1] < min2[1] or max2[0] < min1[0] or max2[1] < min1[1]);
}

pub fn getExtendedAABB(rect1: T.Rect, rect2: T.Rect) T.Rect {
    const minx = @min(rect1.pos[0], rect2.pos[0]);
    const miny = @min(rect1.pos[1], rect2.pos[1]);
    const maxx = @max(rect1.pos[0] + rect1.size[0], rect2.pos[0] + rect2.size[0]);
    const maxy = @max(rect1.pos[1] + rect1.size[1], rect2.pos[1] + rect2.size[1]);
    return T.Rect{ .pos = .{ minx, miny }, .size = .{ maxx - minx, maxy - miny } };
}

fn printNode(node: *const TreeNode, prefix: []const u8, is_last: bool, depth: usize, max_depth: usize) void {
    if (depth >= max_depth) {
        std.debug.print("{s}{s}...(max depth reached)\n", .{prefix, if (is_last) "--- " else "|---"});
        return;
    }
    const connector = if (is_last) "--- " else "|---";
    if (node.data) |plat| {
        std.debug.print("{s}{s}LEAF: pos=({d:.2},{d:.2}) size=({d:.2},{d:.2})\n", .{
            prefix, connector,
            plat.aabb.pos[0], plat.aabb.pos[1],
            plat.aabb.size[0], plat.aabb.size[1],
        });
    } else {
        std.debug.print("{s}{s}BRANCH: aabb pos=({d:.2},{d:.2}) size=({d:.2},{d:.2})\n", .{
            prefix, connector,
            node.aabb.pos[0], node.aabb.pos[1],
            node.aabb.size[0], node.aabb.size[1],
        });
        const extension = if (is_last) "    " else "|   ";
        var new_prefix_buf: [1024]u8 = undefined;
        const new_prefix = std.fmt.bufPrint(&new_prefix_buf, "{s}{s}", .{prefix, extension}) catch prefix;
        const has_bl = node.child_bl != null;
        const has_tr = node.child_tr != null;
        if (has_tr) {
            printNode(node.child_tr.?, new_prefix, !has_bl, depth + 1, max_depth);
        }
        if (has_bl) {
            printNode(node.child_bl.?, new_prefix, true, depth + 1, max_depth);
        }
    }
}
