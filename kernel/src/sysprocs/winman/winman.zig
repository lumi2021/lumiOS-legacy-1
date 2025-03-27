const std = @import("std");
const os = @import("root").os;
const osstd = @import("osstd");

pub fn init(_: ?*anyopaque) callconv(.C) isize {

    osstd.debug.print("Window Manager initialized!\n", .{});

    return 0;
}
