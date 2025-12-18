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
            bvh.root = try bvh.createNode(platform, null);
        }
    }

    fn splitLeaf(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        const old_platform = node.data.?;
        node.data = null;
        node.left = try bvh.createNode(platform, node);
        node.right = try bvh.createNode(old_platform, node);
        node.aabb = getMergedAABB(node.left.?.aabb, node.right.?.aabb);
    }

    fn insertRecursive(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        if (node.isLeaf()) {
            try bvh.splitLeaf(node, platform);
            return;
        }
        const area_current = getAABBCost(node.aabb);
        const merged_aabb = getMergedAABB(node.aabb, platform.aabb);
        const area_merged = getAABBCost(merged_aabb);
        const cost_sibling = area_merged;
        const cost_merge = (area_merged - area_current) * 2.0;
        if (cost_merge < cost_sibling) {
            node.aabb = merged_aabb;
            try bvh.insertIntoChildren(node, platform);
        } else {
            try bvh.insertSibling(node, platform);
        }
    }

    fn insertSibling(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        const old_parent = node.parent;
        const new_branch = try bvh.createBranch(old_parent);
        const new_leaf = try bvh.createNode(platform, new_branch);
        new_branch.left = new_leaf;
        new_branch.right = node; // The old node becomes a child
        new_branch.aabb = getMergedAABB(new_leaf.aabb, node.aabb);
        node.parent = new_branch;
        if (old_parent) |parent| {
            if (parent.left == node) {
                parent.left = new_branch;
            } else {
                parent.right = new_branch;
            }
        } else {
            bvh.root = new_branch;
        }
    }

    fn insertIntoChildren(bvh: *BVH, node: *TreeNode, platform: T.Platform) std.mem.Allocator.Error!void {
        const left = node.left.?;
        const right = node.right.?;
        const merge_l = getMergedAABB(left.aabb, platform.aabb);
        const merge_r = getMergedAABB(right.aabb, platform.aabb);
        const diff_l = getAABBCost(merge_l) - getAABBCost(left.aabb);
        const diff_r = getAABBCost(merge_r) - getAABBCost(right.aabb);
        if (diff_l < diff_r) {
            try bvh.insertRecursive(left, platform);
        } else {
            try bvh.insertRecursive(right, platform);
        }
    }

    fn createNode(bvh: *BVH, platform: T.Platform, parent: ?*TreeNode) !*TreeNode {
        const node = try bvh.allocator.create(TreeNode);
        node.* = .{
            .left = null,
            .right = null,
            .aabb = platform.aabb,
            .data = platform,
            .parent = parent,
        };
        return node;
    }

    fn createBranch(bvh: *BVH, parent: ?*TreeNode) !*TreeNode {
        const node = try bvh.allocator.create(TreeNode);
        node.* = .{
            .left = null,
            .right = null,
            .aabb = undefined,
            .data = null,
            .parent = parent,
        };
        return node;
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
    if (node.parent != null) {
        try aabbs.append(.{
            .x = node.aabb.pos[0],
            .y = node.aabb.pos[1],
            .w = node.aabb.size[0],
            .h = node.aabb.size[1],
        });
    }
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
