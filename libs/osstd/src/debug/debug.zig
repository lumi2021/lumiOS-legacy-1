const std = @import("std");
const root = @import("../osstd.zig");

pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined;
    var wrote = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;
    wrote.len += 1;
    wrote[wrote.len - 1] = 0;

    _ = root.doSystemCall(.write_stdout, @intFromPtr(wrote.ptr), 0, 0, 0);
}
