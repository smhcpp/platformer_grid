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
            bvh.root = try bvh.createLeaf(platform, null);
        }
    }

    fn branchOut(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        node.left = try bvh.createLeaf(platform, node);
        const old_platform = node.data.?;
        node.right = try bvh.createLeaf(old_platform, node);
        node.data = null;
        node.aabb = getMergedAABB(node.left.?.aabb, node.right.?.aabb);
    }

    fn insertRecursive(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        if (node.isLeaf()) {
            try bvh.branchOut(node, platform);
            return;
        }
        const node_cost = getAABBCost(node.aabb);
        const platform_cost = getAABBCost(platform.aabb);
        const merged_aabb = getMergedAABB(node.aabb, platform.aabb);
        const merge_cost = getAABBCost(merged_aabb);
        if (merge_cost < node_cost + platform_cost) {
            node.aabb = merged_aabb;
            try bvh.insertIntoChildren(node, platform);
        } else {
            bvh.insertSibling(node, platform);
        }
    }

    fn insertSibling(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        if (node.parent==null){
            // this node will contain the platform and what ever
            // that was inside of it as children
            return;
        }
        const parent_node = node.parent.?;
        if (node == parent_node.left.?) {
            parent_node.left = try bvh.createEmptyChild(parent_node);
            parent_node.left.?.right = try bvh.createLeaf(platform, parent_node.left);
            parent_node.left.?.left = node;
            parent_node.left.?.aabb = getMergedAABB(node.aabb, platform.aabb);
        } else {
            parent_node.right = try bvh.createEmptyChild(parent_node);
            parent_node.right.?.left = try bvh.createLeaf(platform, parent_node.right);
            parent_node.right.?.right = node;
            parent_node.right.?.aabb = getMergedAABB(node.aabb, platform.aabb);
        }
    }

    fn insertIntoChildren(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        // const aabb_cost = getAABBCost(platform.aabb);
        if (node.left == null) {
            node.left = try bvh.createLeaf(node.left, platform, node);
            return;
        }
        if (node.right.? == null) {
            node.right = try bvh.createLeaf(node.right, platform, node);
            return;
        }
        const left_Merged = getMergedAABB(node.left.?.aabb, platform.aabb);
        const right_Merged = getMergedAABB(node.right.?.aabb, platform.aabb);
        if (left_Merged.cost < right_Merged.cost) {
            try bvh.insertRecursive(node.left.?, platform);
        } else {
            try bvh.insertRecursive(node.right.?, platform);
        }
        // no need to check if right is null because
        // left is null and at least one child is not null
    }

    pub fn printBVH(bvh: *BVH) void {
        std.debug.print("BVH Tree Structure:\n", .{});
        if (bvh.root) |root| {
            printNode(root, "", true, 0, 10);
        } else {
            std.debug.print("  (empty)\n", .{});
        }
    }

    pub fn getAABBs(bvh: *BVH) ![]const T.RectGPU {
        var aabbs = std.ArrayList(T.RectGPU).init(bvh.allocator);
        defer aabbs.deinit();
        if (bvh.root) |root| {
            try getAABBsRecursive(root, &aabbs);
        }
        return aabbs.toOwnedSlice();
    }

    fn createLeaf(bvh: *BVH, platform: T.Platform, parent: ?*TreeNode) !*TreeNode {
        const node = try bvh.allocator.create(TreeNode);
        node.* = .{
            .right = null,
            .left = null,
            .aabb = platform.aabb,
            .data = platform,
            .parent = parent,
        };
        return node;
    }

    fn createEmptyChild(bvh: *BVH, parent: ?*TreeNode) !*TreeNode {
        const node = try bvh.allocator.create(TreeNode);
        node.* = .{
            .right = null,
            .left = null,
            .aabb = parent.aabb,
            .data = null,
            .parent = parent,
        };
        return node;
    }
};

pub const TreeNode = struct {
    right: ?*TreeNode,
    left: ?*TreeNode,
    aabb: T.Rect,
    data: ?T.Platform,
    parent: ?*TreeNode,

    pub fn isLeaf(node: *const TreeNode) bool {
        return node.data != null;
    }

    pub fn deinit(node: *TreeNode, allocator: std.mem.Allocator) void {
        if (node.right) |tr| tr.deinit(allocator);
        if (node.left) |bl| bl.deinit(allocator);
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

pub fn getMergedAABB(rect1: T.Rect, rect2: T.Rect) T.Rect {
    const minx = @min(rect1.pos[0], rect2.pos[0]);
    const miny = @min(rect1.pos[1], rect2.pos[1]);
    const maxx = @max(rect1.pos[0] + rect1.size[0], rect2.pos[0] + rect2.size[0]);
    const maxy = @max(rect1.pos[1] + rect1.size[1], rect2.pos[1] + rect2.size[1]);
    return T.Rect{ .pos = .{ minx, miny }, .size = .{ maxx - minx, maxy - miny } };
}

pub fn getAABBCost(rect: T.Rect) f32 {
    return rect.size[0] + rect.size[1];
}

fn getAABBsRecursive(node: *const TreeNode, aabbs: *std.ArrayList(T.RectGPU)) std.mem.Allocator.Error!void {
    if (node.isLeaf()) return;
    try aabbs.append(.{
        .x = node.aabb.pos[0],
        .y = node.aabb.pos[1],
        .w = node.aabb.size[0],
        .h = node.aabb.size[1],
    });
    if (node.right) |tr| {
        try getAABBsRecursive(tr, aabbs);
    }
    if (node.left) |bl| {
        try getAABBsRecursive(bl, aabbs);
    }
}

fn printNode(node: *const TreeNode, prefix: []const u8, is_last: bool, depth: usize, max_depth: usize) void {
    if (depth >= max_depth) {
        std.debug.print("{s}{s}...(max depth reached)\n", .{ prefix, if (is_last) "--- " else "|---" });
        return;
    }
    const connector = if (is_last) "--- " else "|---";
    if (node.data) |plat| {
        std.debug.print("{s}{s}LEAF: pos=({d:.2},{d:.2}) size=({d:.2},{d:.2})\n", .{
            prefix,            connector,
            plat.aabb.pos[0],  plat.aabb.pos[1],
            plat.aabb.size[0], plat.aabb.size[1],
        });
    } else {
        std.debug.print("{s}{s}BRANCH: aabb pos=({d:.2},{d:.2}) size=({d:.2},{d:.2})\n", .{
            prefix,            connector,
            node.aabb.pos[0],  node.aabb.pos[1],
            node.aabb.size[0], node.aabb.size[1],
        });
        const extension = if (is_last) "    " else "|   ";
        var new_prefix_buf: [1024]u8 = undefined;
        const new_prefix = std.fmt.bufPrint(&new_prefix_buf, "{s}{s}", .{ prefix, extension }) catch prefix;
        const has_bl = node.left != null;
        const has_tr = node.right != null;
        if (has_tr) {
            printNode(node.right.?, new_prefix, !has_bl, depth + 1, max_depth);
        }
        if (has_bl) {
            printNode(node.left.?, new_prefix, true, depth + 1, max_depth);
        }
    }
}
