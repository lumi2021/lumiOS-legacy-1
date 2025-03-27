const std = @import("std");
const os = @import("root").os;
const osstd = @import("osstd");
const gl = os.GL;

const sysprocs = @import("../sysprocs.zig");

// Adam is a better term for the first father of all tasks 
// than root was! - Terry A. Davis

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    osstd.debug.print("Adam initialized\n", .{});

    osstd.debug.print("Initializing Window manager...\n", .{});
    _ = osstd.process.create_thead("winman", sysprocs.winman.init, null);

    while (true) {

    }
}
