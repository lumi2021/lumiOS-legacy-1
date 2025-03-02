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
pub const vfs = @import("vfs.zig");

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

pub fn init() !void {
    st.push(@src()); defer st.pop();
    write.log("Initializing file system...", .{});
}

pub fn open_file_descriptor(path: [:0]u8, flags: FileAccessFlags) OpenFileError!isize {
    st.push(@src()); defer st.pop();

    write.log("Trying to open file \"{s}\" (len {})", .{ path, path.len });

    const task = schedue.current_task.?;
    const handler: isize = @intCast(task.get_resource_index() catch 0);
    errdefer task.free_resource_index(@bitCast(handler)) catch unreachable;

    if (path.len >= 6 and std.mem.eql(u8, path[0..5], "sys:/")) {
        try vfs.open_virtual_file(&task.resources[@bitCast(handler)], path, flags);
    
    } else {

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


pub const OpenFileError = error{
    fileNotFound,
    accessDenied,
    invalidDescriptor,
    notAFile,
    Undefined,
};
