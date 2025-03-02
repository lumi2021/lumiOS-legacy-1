const std = @import("std");
const os = @import("root").os;
const schedue = os.theading.schedue;

const Task = os.theading.Task;
const ResourceHandler = os.system.ResourceHandler;
const ResourceKind = ResourceHandler.Kind;

const st = os.stack_tracer;
const write = os.console_write("vfs");

const fs = @import("fs.zig");
const FileAccessFlags = fs.FileAccessFlags;

var allocator: std.heap.ArenaAllocator = undefined;
var root: *FsNode = undefined;

const FsNode = @import("fsnode.zig").FsNode;

pub fn init() !void {
    st.push(@src()); defer st.pop();
    write.log("Initializing virtual file system...", .{});

    allocator = std.heap.ArenaAllocator.init(os.memory.allocator);

    root = FsNode.init("sys:", .directory);

    _ = root.branch("dev", .directory);
    const proc = root.branch("proc", .directory); {
        _ = proc.branch("self", .directory);
    }
}

pub fn open_virtual_file(res: *ResourceHandler, path: [:0]const u8, flags: FileAccessFlags) !void {

    _ = res;
    _ = flags;

    var iter = std.mem.tokenize(u8, path[5..], "/");
    var cur: *FsNode = root;

    var step = iter.next();
    while (step != null) : (step = iter.next()) {

        if (cur.getChild(step.?)) |c| { cur = c; }
        else return error.fileNotFound;

    }

    switch (cur.kind) {
        
        .device => unreachable,
        .pipe => {

            

        },

        else => return error.notAFile

    }

}

