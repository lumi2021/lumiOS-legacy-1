const os = @import("root").os;
const std = @import("std");

const disk = os.drivers.disk;
const fs = os.fs;

const ResourceHandler = os.system.ResourceHandler;
const ResourceKind = ResourceHandler.Kind;

const st = os.stack_tracer;

pub const FsNodeList = std.ArrayList(*FsNode);

pub const FsNode = struct {
    name: []u8,

    parent: ?*FsNode,

    children: FsNodeList,
    permissions: struct {
        read: bool,
        write: bool,
        execute: bool,
    },
    data: FsNodeData,

    pub fn init(name: []const u8, data: FsNodeData) *@This() {
        st.push(@src()); defer st.pop();
        
        const alloc = fs.allocator;
    
        const this = alloc.create(FsNode) catch unreachable;
        this.name = alloc.alloc(u8, name.len) catch unreachable;
        @memcpy(this.name.ptr, name);
        this.data = data;
        this.children = FsNodeList.init(alloc);
        
        return this;
    }
    
    pub fn deinit(this: *@This()) void {
        const alloc = fs.allocator;

        // Deinit children
        for (this.children.items) |e| e.deinit();
        this.children.deinit();

        // free heap data
        alloc.free(this.name);
        alloc.free(this);
    }
    pub fn deinit_children(this: *@This()) void {
        _ = this;
        // TODO
        //
    }

    pub inline fn kind(s: *@This()) ResourceKind {
        return s.data;
    }

    pub fn branch(this: *@This(), name: []const u8, data: FsNodeData) *@This() {
        st.push(@src()); defer st.pop();

        // Create new instance
        const new = FsNode.init(name, data);
        // Add as child
        this.children.append(new) catch unreachable;

        // Set child's parent data
        new.parent = this;

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
    partition: DiskPartition,

    file: void,
    directory: void,
    virtual_directory: void,
    symlink: FsNodeSymlink,
    pipe: FsNodePipe,
    sharedPipe: FsNodePipe,
};

pub const DiskPartition = struct {
    sectors_start: u32,
    sectors_end: u32,
    part_type: fs.partitions.PartitionType
};

pub const FsNodePipe = struct {
    pipePtr: *os.theading.task_resources.Pipe
};
pub const FsNodeSymlink = struct {
    linkTo: []const u8
};
