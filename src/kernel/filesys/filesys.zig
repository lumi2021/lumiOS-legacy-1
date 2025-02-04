const std = @import("std");
const root = @import("root");
const os = root.os;

const write = os.console_write("filesys");

pub const FileAccessFlags = packed struct(u64) {
    read: bool,
    write: bool,
    execute: bool,

    create_new: bool,
    _: u60
};

pub fn open_file_descriptor(path: [:0]u8, flags: FileAccessFlags) i64 {
    _ = flags;

    write.log("Trying to open file \"{s}\" (len {})", .{path, path.len});
    if (path.len >= 6 and std.mem.eql(u8, path[0..5], "sys:/")) {
        write.log("is system virtual directory", .{});
    }

    return -1;   
}
