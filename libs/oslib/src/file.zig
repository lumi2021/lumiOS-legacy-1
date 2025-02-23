const oslib = @import("oslib.zig");

pub const FileAccessFlags = packed struct(u64) {
    read: bool = false,
    write: bool = false,
    execute: bool = false,

    create_new: bool = false,
    _: u60 = undefined
};

pub fn open(path: [:0]u8, flags: FileAccessFlags) i64 {
    return @bitCast(oslib.raw_system_call(
        .open_file_descriptor,
        @intFromPtr(path.ptr),
        @bitCast(flags),
        0, 0
    ));
}
