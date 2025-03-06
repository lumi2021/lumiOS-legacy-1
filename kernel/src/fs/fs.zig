const std = @import("std");
const os = @import("root").os;
const schedue = os.theading.schedue;

const Task = os.theading.Task;
const ResourceHandler = os.system.ResourceHandler;

const FAT = @import("formats/FAT.zig");

const disk = os.drivers.disk;

const write = os.console_write("fs");
const st = os.stack_tracer;

pub const FsNode = @import("fsnode.zig").FsNode;

// File system:
//     <letter>:/      - default partitions
//     sys:/           - virtual directories
//      |- dev/        - devices
//      '_ proc/       - processes
//          |- self    - caller process dir
//          '- <pid>   - specific process dir

pub const FileAccessFlags = packed struct(u64) {
    read: bool,
    write: bool,
    execute: bool,
    create_new: bool,
    _: u60,
};

var allocator: std.heap.ArenaAllocator = undefined;
var fileTree: struct {

    drives: []*FsNode,

    sys: *FsNode,
    dev: *FsNode,

} = undefined;


pub fn init() !void {
    st.push(@src()); defer st.pop();
    write.log("Initializing file system...", .{});

    allocator = std.heap.ArenaAllocator.init(os.memory.allocator);

    fileTree.sys = FsNode.init("sys:", .{ .directory = undefined });

    const dev = fileTree.sys.branch("dev", .{ .directory = undefined }); {
        _ = dev;
    }
    const proc = fileTree.sys.branch("proc", .{ .directory = undefined }); {
        _ = proc.branch("self", .{ .symlink = .{ .linkTo = "sys:/proc/$PROC_ID" } });
    }
}

pub fn open_file_descriptor(path: [:0]u8, flags: FileAccessFlags) OpenFileError!isize {
    st.push(@src()); defer st.pop();

    // global paths can only start with `[c]:/` so aways at least 3 characters
    if (path.len < 3) return error.invalidPath;

    write.log("Trying to open file \"{s}\" (len {})", .{ path, path.len });

    const task = schedue.current_task.?;
    const handler: isize = @intCast(task.get_resource_index() catch 0);
    errdefer task.free_resource_index(@bitCast(handler)) catch unreachable;

    _ = flags;

    var iter = std.mem.tokenizeAny(u8, path, "/");
    var cur: *FsNode = try get_tree_root(iter.next().?);

    var s = iter.next();
    while (s != null) : ({
        s = iter.next();
        write.dbg("{s}", .{s orelse "null"});
    }) {
        var step = s.?;

        // variables
        if (step[0] == '$') {

            if (std.mem.eql(u8, step[1..], "PROC_ID")) {
                write.log("iterating: {s} - variable", .{step});

                var str: [16]u8 = undefined;
                const l = std.fmt.formatIntBuf(&str, task.id, 16, .lower, .{});
                cur = cur.getChild(str[0..l]).?;
            }

            else return error.fileNotFound;
        }

        else if (cur.getChild(step)) |c| {
            write.log("iterating: {s} - {s}", .{step, @tagName(c.kind())});

            switch (c.data) {
                .symlink => {
                    iter = std.mem.tokenizeAny(u8, c.data.symlink.linkTo, "/");
                    s = iter.next();

                    if (s == null) return error.invalidPath
                    else if (s.?[s.?.len - 1] == ':') cur = try get_tree_root(s.?)
                    else iter.reset();
                },
                .directory => cur = c,

                else => return error.fileNotFound
            }
        }
        else return error.fileNotFound;

    }

    return handler;
}
pub fn close_file_descriptor(handler: usize) void {
    write.log("Closing file descriptor {}", .{handler});

    const current_task = schedue.current_task.?;
    // TODO handle error
    current_task.free_resource_index(handler) catch unreachable;
}

fn write_file_descriptor(task: *Task, file: usize, data: []u8) OpenFileError!isize {
    st.push(@src()); defer st.pop();

    _ = task;
    _ = file;
    _ = data;
}


fn get_tree_root(token: []const u8) error{invalidPath}!*FsNode {
    st.push(@src()); defer st.pop();
    errdefer write.dbg("{s} was not a root!", .{token});

    write.dbg("testing if {s} is root or not", .{token});

    if (token.len <= 3 or token[token.len - 1] != ':') return error.invalidPath;

    if (token.len == 4 and std.mem.eql(u8, token, "sys:")) return fileTree.sys
    else if (token.len == 4 and std.mem.eql(u8, token, "dev:")) return fileTree.dev
    else return error.invalidPath;
}

pub const OpenFileError = error{
    fileNotFound,
    invalidPath,
    accessDenied,
    invalidDescriptor,
    notAFile,
    Undefined,
};
