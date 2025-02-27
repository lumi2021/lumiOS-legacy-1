const std = @import("std");
const os = @import("root").os;
const schedue = os.theading.schedue;

const Task = os.theading.Task;

const FAT = @import("formats/FAT.zig");

const disk = os.drivers.disk;

const write = os.console_write("Filesys");
const st = os.stack_tracer;

// File system:
//     <letter>:/   - default partitions
//     sys:/        - virtual directories
//     sys:/dev/    - devices
//     sys:/proc/   - processes

pub const FileAccessFlags = packed struct(u64) { read: bool, write: bool, execute: bool, create_new: bool, _: u60 };

pub fn init() !void {
    st.push(@src());
    defer st.pop();
    write.log("Initializing file system...", .{});
}

pub fn open_file_descriptor(path: [:0]u8, flags: FileAccessFlags) OpenFileError!isize {
    st.push(@src());
    defer st.pop();

    write.log("Trying to open file \"{s}\" (len {})", .{ path, path.len });

    const current_task = schedue.current_task.?;

    if (path.len >= 6 and std.mem.eql(u8, path[0..5], "sys:/")) {
        write.log("is system virtual directory", .{});
        return open_virtual_file_descriptor(current_task, path[5..], flags);
    }
    return open_real_file_descriptor(current_task, path, flags);
}
pub fn close_file_descriptor(handler: usize) void {
    write.log("Closing file descriptor {}", .{handler});

    const current_task = schedue.current_task.?;
    // TODO handle error
    current_task.free_resource_index(handler) catch unreachable;
}

fn open_real_file_descriptor(task: *Task, path: [:0]u8, flags: FileAccessFlags) OpenFileError!isize {
    st.push(@src());
    defer st.pop();

    _ = path;
    _ = flags;

    const handler: isize = @intCast(task.get_resource_index() catch 0);
    return handler;
}

fn open_virtual_file_descriptor(task: *Task, path: [:0]u8, flags: FileAccessFlags) OpenFileError!isize {
    st.push(@src());
    defer st.pop();

    _ = path;
    _ = flags;

    const handler: isize = @intCast(task.get_resource_index() catch 0);
    return handler;
}

pub const OpenFileError = error{ fileNotFound, accessDenied, Undefined };
