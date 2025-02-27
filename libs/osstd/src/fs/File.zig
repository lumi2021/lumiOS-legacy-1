const root = @import("../osstd.zig");

descriptor: i64,
flags: AccessFlags,
kind: Kind,

pub fn open(path: [:0]u8, flags: AccessFlags) FileError!@This() {
    const syscall_res = root.doSystemCall(.open_file_descriptor, @intFromPtr(path.ptr), @bitCast(flags), 0, 0);

    if (syscall_res.err != .NoError) return switch (syscall_res.err) {
        .FileNotFound => error.fileNotFound,
        .AccessDenied => error.accessDenied,
        else => error.Undefined,
    };

    const descriptor: isize = @bitCast(syscall_res.res);

    return .{
        .descriptor = descriptor,
        .flags = flags,
        .kind = .file,
    };
}
pub fn close(self: @This()) void {
    if (self.descriptor == -1) @panic("Invalid descriptor!");
    _ = root.doSystemCall(.close_file_descriptor, @bitCast(self.descriptor), 0, 0, 0);
}

pub fn writeBytes(self: @This(), data: []u8) FileError!void {
    _ = self;
    _ = data;
}
pub fn readBytes(self: @This()) FileError!void {
    _ = self;
}

pub const Kind = enum {
    file,
    directory,
    device,
    input_output,
};
pub const AccessFlags = packed struct(u64) {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    create_new: bool = false,
    _: u60 = undefined,
};
pub const FileError = error{
    fileNotFound,
    accessDenied,
    Undefined,
};
