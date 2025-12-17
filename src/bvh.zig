const std = @import("std");
const T = @import("types.zig");

pub const BVH = struct {
    root: ?*TreeNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, map_shape: T.Rect) !*BVH {
        const bvh = try allocator.create(BVH);
        bvh.* = .{
            .root = .{
                .child_tr = null,
                .child_bl = null,
                .type = .{ .branch = map_shape },
            },
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

    pub fn insert(bvh:*BVH, platform:T.Platform) !void {
        const root = bvh.root;
        const center = platform.shape.center();
        var is_horizontal = switch(root.type){
            .branch => |branch| {
                branch.size[0] >= branch.size[1];
            },
            .leaf => false,
        };

    }

    pub fn insertRect(bvh: *BVH, parent: ?*TreeNode, rect: T.Rect) !void {
        const center = T.Rect.center(rect);
        if (parent) |parent_node| {
            const is_horizental = parent_node.aabb.size[0] >= parent_node.aabb.size[1];
            const is_tr = (is_horizental and center[0] >= parent_node.aabb.center[0]) or
                (!is_horizental and center[1] >= parent_node.aabb.center[1]);
            if (is_tr) {
                if (parent_node.child_tr) |tr_node| {
                    try tr_node.insertRect(rect);
                    return;
                }
                try bvh.createNode(parent_node.child_tr, rect);
            } else {
                if (parent_node.child_tl) |tl_node| {
                    try tl_node.insertRect(rect);
                    return;
                }
                try bvh.createNode(parent_node.child_tl, rect);
            }
            return;
        }
        try bvh.createNode(parent, rect);
    }

    fn createNode(bvh: *BVH, node: ?*TreeNode, rect: T.Rect) !void {
        node = try bvh.allocator.create(TreeNode);
        node.* = .{
            .child_tr = null,
            .child_bl = null,
            .aabb = rect,
        };
    }
};

/// tr: top or right
/// bl: bot or left
pub const TreeNode = struct {
    child_tr: ?*TreeNode,
    child_bl: ?*TreeNode,
    type: NodeType,
    pub fn deinit(node: *TreeNode, allocator: std.mem.Allocator) void {
        if (node.child_tr) |tr_node| {
            tr_node.deinit(allocator);
        }
        if (node.child_bl) |bl_node| {
            bl_node.deinit(allocator);
        }
        allocator.destroy(node);
    }
};

pub const NodeType = union {
    leaf: T.Platform,
    branch: T.Rect,
};
