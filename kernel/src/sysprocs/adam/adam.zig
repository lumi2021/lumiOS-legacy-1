const std = @import("std");
const os = @import("root").os;
const osstd = @import("osstd");
const gl = os.GL;

// Adam is a better term for the first father of all tasks 
// than root was! - Terry A. Davis

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    osstd.debug.print("Adam initialized\n", .{});

    while (true) {

    }
}
