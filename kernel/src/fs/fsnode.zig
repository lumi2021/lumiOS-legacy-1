const os = @import("root").os;
const std = @import("std");

const disk = os.drivers.disk;

const ResourceHandler = os.system.ResourceHandler;
const ResourceKind = ResourceHandler.Kind;

const st = os.stack_tracer;

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
        st.push(@src()); defer st.pop();
        
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
        st.push(@src()); defer st.pop();

        const new = FsNode.init(name, data);
        this.children.append(new) catch unreachable;
        return new;
    }

    pub fn getChild(this: *@This(), name: []const u8) ?*@This() {
        st.push(@src()); defer st.pop();
        
        for (this.children.items) |i| {
            if (std.mem.eql(u8, i.name, name)) return i;
        }
        return null;
    }
};

pub const FsNodeData = union(ResourceKind) {
    device: void,
    disk: disk.DiskEntry,

    file: void,
    directory: void,
    virtual_directory: void,
    symlink: FsNodeSymlink,
    pipe: FsNodePipe,
    sharedPipe: FsNodePipe,
};

pub const FsNodePipe = struct {
    pipePtr: *os.theading.Pipe
};
pub const FsNodeSymlink = struct {
    linkTo: []const u8
};
