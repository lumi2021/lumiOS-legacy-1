const os = @import("root").os;
const std = @import("std");

const ResourceHandler = os.system.ResourceHandler;
const ResourceKind = ResourceHandler.Kind;

pub const FsNodeList = std.ArrayList(*FsNode);

pub const FsNode = struct {
    name: []u8,
    parent: *FsNode,
    children: FsNodeList,
    permissions: struct {
        read: bool,
        write: bool,
        execute: bool,
    },
    data: FsNodeData,

    pub fn init(name: []const u8, data: FsNodeData) *@This() {
        const alloc = os.memory.allocator;
    
        const this = alloc.create(FsNode) catch unreachable;
        this.name = alloc.alloc(u8, name.len) catch unreachable;
        @memcpy(this.name.ptr, name);
        this.data = data;
        this.children = FsNodeList.init(alloc);
        
        return this;
    }
    pub fn deinit(this: *@This()) void {
        const alloc = os.memory.allocator;

        alloc.free(this.name);
        this.children.deinit();
        alloc.free(this);
    }

    pub inline fn kind(s: *@This()) ResourceKind {
        return s.data;
    }

    pub fn branch(this: *@This(), name: []const u8, data: FsNodeData) *@This() {
        const new = FsNode.init(name, data);
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

pub const FsNodeData = union(ResourceKind) {
    device: void,
    disk: void,

    file: void,
    directory: void,
    virtual_directory: void,
    symlink: FsNodeSymlink,
    pipe: FsNodePipe,
};

pub const FsNodePipe = struct {
    pipePtr: *os.theading.Pipe
};
pub const FsNodeSymlink = struct {
    linkTo: []const u8
};
