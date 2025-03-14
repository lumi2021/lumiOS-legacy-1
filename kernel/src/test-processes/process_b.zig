const std = @import("std");
const os = @import("root").os;
const osstd = @import("osstd");

const write = os.console_write("Process B");
const mem = os.memory;

pub fn init(_: ?*anyopaque) callconv(.C) isize {

    osstd.debug.print("Hello world from process B!\n", .{});

    const stdio_path = std.fmt.allocPrintZ(mem.allocator, "sys:/proc/self/stdio", .{}) catch unreachable;
    const stdio = osstd.fs.openFileAbsolute(stdio_path, .{ .read = true, .write = true })
       catch |err| { @panic(@errorName(err)); };

    while (true) {

        // TODO read stdio file descriptor and write process_a
        // output logs

        _ = stdio;

    }

}
