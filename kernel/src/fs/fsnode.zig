const os = @import("root").os;
const std = @import("std");

const ResourceHandler = os.system.ResourceHandler;
const ResourceKind = ResourceHandler.Kind;

const FsNodeList = std.ArrayList(*FsNode);
pub const FsNode = struct {
    name: []u8,
    children: FsNodeList,
    kind: ResourceKind,

    permissions: struct {
        read: bool,
        write: bool,
        execute: bool,
    },

    data: union(ResourceKind) {
        file: void,
        directory: void,
        symlink: void,
        device: void,
        pipe: FsNodePipe,
    },

    pub fn init(name: []const u8, k: ResourceKind) *@This() {
        const alloc = os.memory.allocator;

        const this = alloc.create(FsNode) catch unreachable;
        this.name = alloc.alloc(u8, name.len) catch unreachable;
        this.name = @constCast(name);
        this.kind = k;
        this.children = FsNodeList.init(alloc);

        return this;
    }
    pub fn deinit(this: *@This()) void {
        const alloc = os.memory.allocator;

        alloc.free(this.name);
        this.children.deinit();
        alloc.free(this);
    }

    pub fn branch(this: *@This(), name: []const u8, k: ResourceKind) *@This() {
        const new = FsNode.init(name, k);
        this.children.append(new) catch unreachable;
        return new;
    }

    pub fn getChild(this: *@This(), name: []const u8) ?*@This() {
        for (this.children.items) |i| {
            if (std.mem.eql(u8, i.name, name)) return i;
        }
        return null;
    }
};

pub const FsNodePipe = struct {

};
