const std = @import("std");
const uefi = std.os.uefi;
const fmt = std.fmt;
const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

pub var out: *uefi.protocol.SimpleTextOutput = undefined;

pub fn puts(msg: []const u8) void {
    for (msg) |c| {
        const c_ = [2]u16{ c, 0 };
        _ = out.outputString(@ptrCast(&c_));
    }
}
pub fn printf(comptime format: []const u8, args: anytype) void {
    puts(fmt.bufPrint(undefined, format, args) catch unreachable);
}
