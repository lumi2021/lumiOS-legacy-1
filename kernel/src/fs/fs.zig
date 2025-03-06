// File system:
//     <letter>:/      - default partitions
//     sys:/           - virtual system directories
//      '_ proc/       - processes
//          |- self    - caller process dir
//          '- <pid>   - specific process dir
//     dev:/           - virtual device interfaces

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
        _ = proc.branch("self", .{ .symlink = .{ .linkTo = "sys:/proc/$THREAD_ID" } });
    }
}

pub fn ls(path: []const u8) void {
    lsnode(solve_path(path) catch |err| {
        write.err("error: {s}", .{@errorName(err)});
        return;
    });
}
pub fn lsnode(node: *FsNode) void {
    for (node.children.items) |e| {
        write.raw("{s: <15}{s}\n", .{e.name, @tagName(e.kind())});
    }
}

pub fn make_dir(path: []const u8) (OpenPathError || CreateError)!*FsNode {
    st.push(@src()); defer st.pop();

    const last_slash = std.mem.lastIndexOf(u8, path, "/") orelse return OpenPathError.invalidPath;
    const subpath = path[0..last_slash];
    
    var subdir = try solve_path(subpath);
    if (subdir.kind() != .directory) return OpenPathError.notADirectory;

    if (subdir.getChild(path[(last_slash + 1)..]) != null) return error.nameAlreadyExists;
    return subdir.branch(path[(last_slash + 1)..], .{ .directory = undefined });
}
pub fn make_file(path: []const u8, data: FsNodeData) (OpenPathError || CreateError)!void {
    st.push(@src()); defer st.pop();

    const last_slash = std.mem.lastIndexOf(u8, path, "/") orelse return OpenPathError.invalidPath;
    const subpath = path[0..last_slash];
    
    var subdir = try solve_path(subpath);
    if (subdir.kind() != .directory) return OpenPathError.notADirectory;

    if (subdir.getChild(path[(last_slash + 1)..]) != null) return error.nameAlreadyExists;
    return subdir.branch(path[(last_slash + 1)..], data);
}

// system call actions
pub fn open_file_descriptor(path: [:0]u8, flags: FileAccessFlags) OpenFileError!isize {
    st.push(@src()); defer st.pop();

    // global paths can only start with `[c]:/` so aways at least 3 characters
    if (path.len < 3) return error.invalidPath;

    write.log("Trying to open file \"{s}\" (len {})", .{ path, path.len });

    const task = schedue.current_task.?;
    const handler: isize = @intCast(task.get_resource_index() catch 0);
    errdefer task.free_resource_index(@bitCast(handler)) catch unreachable;

    _ = flags;

    const file = try solve_path(path);
    _ = file;

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

fn solve_path(path: []const u8) OpenPathError!*FsNode {
    st.push(@src()); defer st.pop();

    var iter = std.mem.tokenizeAny(u8, path, "/");
    var cur: *FsNode = try get_tree_root(iter.next().?);

    var s = iter.next();
    while (s != null) : (s = iter.next()) {
        var step = s.?;

        // variables
        if (step[0] == '$') {

            if (std.mem.eql(u8, step[1..], "THREAD_ID")) {
                var str: [16]u8 = undefined;
                step = std.fmt.bufPrint(&str, "{X:0>5}", .{schedue.current_task.?.id}) catch unreachable;
            }
            else return error.pathNotFound;
        }

        if (cur.getChild(step)) |c| {
            switch (c.data) {
                .symlink => {
                    write.log("branching into symbolic link \"{s}\"", .{c.data.symlink.linkTo});
                    cur = try solve_path(c.data.symlink.linkTo);
                    if (cur.kind() != .directory) return error.notADirectory;
                },
                .directory => cur = c,
                
                else => return c
            }
        }
        else {
            write.warn("searching for: {s}", .{step});
            lsnode(cur);
            return error.pathNotFound;
        }
    }

    return cur;
}
fn get_tree_root(token: []const u8) OpenPathError!*FsNode {
    st.push(@src()); defer st.pop();

    if (token.len <= 3 or token[token.len - 1] != ':') return error.invalidPath;

    // TODO normal drives
    if (token.len == 4 and std.mem.eql(u8, token, "sys:")) return fileTree.sys
    else if (token.len == 4 and std.mem.eql(u8, token, "dev:")) return fileTree.dev

    else return error.invalidPath;
}

// imports
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
pub const FsNodeData = @import("fsnode.zig").FsNodeData;

// error tables
pub const FsError = OpenFileError || OpenPathError;

pub const OpenFileError = error {
    fileNotFound,
    notAFile,
    invalidDescriptor,
}
|| OpenPathError
|| PermitionError
|| GeneralError;

pub const OpenPathError = error {
    invalidPath,
    pathNotFound,
    notADirectory
}
|| GeneralError;

pub const CreateError = error {
    nameAlreadyExists
}
|| OpenPathError
|| PermitionError
|| GeneralError;

pub const PermitionError = error {
    accessDenied
};

pub const GeneralError = error { Undefined };
