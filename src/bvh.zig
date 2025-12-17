const std = @import("std");
const T = @import("types.zig");
const Vec2 = T.Vec2;

pub const BVH = struct {
    root: ?*TreeNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*BVH {
        const bvh = try allocator.create(BVH);
        bvh.* = .{
            .root =  null,
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

    pub fn insert(bvh:*BVH,platform:T.Platform) !void{
        try bvh.insertNode(bvh.root,platform);
    }

    fn insertNode(bvh:*BVH,parent:?*TreeNode, platform:T.Platform) !void {
        if (parent) |parent_node|{
            parent_node.aabb = getExtendedAABB(parent_node.aabb, platform.aabb);
            const new_center = platform.aabb.center();
            if(parent_node.child_bl)|bl|{
                if(parent_node.child_tr)|tr|{
                    const distance = (tr.aabb.center() - bl.aabb.center())/Vec2{2, 2};
                    const center = (bl.aabb.center() + tr.aabb.center())/Vec2{2, 2};
                    const separation_index:usize = if(@abs(distance[0]) >= @abs(distance[1])) 0 else 1;
                    const is_tr= new_center[separation_index] >= center[separation_index];
                    if(is_tr){
                        try bvh.insertNode(parent_node.child_tr,platform);
                    }else{
                        try bvh.insertNode(parent_node.child_bl,platform);
                    }
                }else{
                    const bl_center = bl.aabb.center();
                    const distance = (new_center - bl_center)/Vec2{2, 2};
                    const separation_index:usize = if(@abs(distance[0]) >= @abs(distance[1])) 0 else 1;
                    const is_tr= new_center[separation_index] >= bl_center[separation_index];
                    if (is_tr){
                        try bvh.createNode(&parent_node.child_tr, platform);
                    }else{
                        parent_node.child_tr=parent_node.child_bl;
                        try bvh.createNode(&parent_node.child_bl, platform);
                    }
                }
            }else{
                if(parent_node.child_tr)|tr|{
                    const tr_center = tr.aabb.center();
                    const distance = (new_center - tr_center)/Vec2{2, 2};
                    const separation_index:usize = if(@abs(distance[0]) >= @abs(distance[1])) 0 else 1;
                    const is_tr= new_center[separation_index] >= tr_center[separation_index];
                    if (is_tr){
                        parent_node.child_bl=parent_node.child_tr;
                        try bvh.createNode(&parent_node.child_tr, platform);
                    }else{
                        try bvh.createNode(&parent_node.child_bl, platform);
                    }
                }else{
                    try bvh.createNode(&parent_node.child_tr, platform);
                }
            }

        }else{
            try bvh.createNode(&parent,platform);
        }
    }

    fn createNode(bvh: *BVH, node: *const ?*TreeNode, plat: T.Platform) !void {
        node.*.? = try bvh.allocator.create(TreeNode);
        node.*.?.* = .{
            .child_tr = null,
            .child_bl = null,
            .aabb = plat.aabb,
            .data = plat,
        };
    }
};

/// tr: top or right
/// bl: bot or left
pub const TreeNode = struct {
    child_tr: ?*TreeNode,
    child_bl: ?*TreeNode,
    aabb: T.Rect,
    data: ?T.Platform,
    pub fn deinit(node: *TreeNode, allocator: std.mem.Allocator) void {
        if (node.child_tr) |tr| tr.deinit(allocator);
        if (node.child_bl) |bl| bl.deinit(allocator);
        // if (node.data) |data| allocator.destroy(data);
        allocator.destroy(node);
    }
};

/// assumes that size for each rect is positive
pub fn isAABBCollision(rect1: T.Rect, rect2: T.Rect) bool {
    const min1 = rect1.pos;
    const max1 = rect1.pos + rect1.size;
    const min2 = rect2.pos;
    const max2 = rect2.pos + rect2.size;
    return !(max1[0] < min2[0] or max1[1] < min2[1] or max2[0] < min1[0] or max2[1] < min1[1]);
}

pub fn getExtendedAABB(rect1:T.Rect, rect2:T.Rect) T.Rect{
    const minx = @min(rect1.pos[0], rect2.pos[0]);
    const miny = @min(rect1.pos[1], rect2.pos[1]);
    const maxx = @max(rect1.pos[0] + rect1.size[0], rect2.pos[0] + rect2.size[0]);
    const maxy = @max(rect1.pos[1] + rect1.size[1], rect2.pos[1] + rect2.size[1]);
    return T.Rect{.pos = .{minx, miny}, .size = .{maxx - minx, maxy - miny}};
}
