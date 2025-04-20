const std = @import("std");
const os = @import("root").os;
const debug_log = os.debug_log;
const osstd = @import("osstd");
const gl = os.gl;

const sysprocs = @import("../sysprocs.zig");

const print = os.console_write("Adam");

// Adam is a better term for the first father of all tasks
// than root was! - Terry A. Davis

var debug_ptr: usize = 0;

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    print.log("Adam initialized\n", .{});

    print.log("# Initializing drivers...", .{});
    _ = osstd.process.create_task("adam branch", init_all_drivers_async, null);

    print.log("# Initializing Window manager...\n", .{});
    _ = osstd.process.create_task("winman", sysprocs.winman.init, null);

    print.log("Adam initialization routine complete.\n", .{});
    
    while (true) {}
}

pub fn init_all_drivers_async(_: ?*anyopaque) callconv(.C) isize {
    os.drivers.init_all_drivers() catch |err| @panic(@errorName(err));
    return 0;
}

pub fn shutdown() noreturn {
    os.port_io.outw(0x0604, 0x2000);
    unreachable;
}
