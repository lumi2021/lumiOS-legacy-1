const std = @import("std");
const os = @import("root").os;
const osstd = @import("osstd");

const write = os.console_write("Process A");
const mem = os.memory;

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    osstd.debug.print("Hello, World from process A!\n", .{});

    const kbd_path = std.fmt.allocPrintZ(mem.allocator, "sys:/dev/input/kbd.event", .{}) catch unreachable;
    const stdio_path = std.fmt.allocPrintZ(mem.allocator, "sys:/dev/stdio", .{}) catch unreachable;

    osstd.debug.print("Requesting keyboard and std IO access\n", .{});
    const kbd = osstd.fs.openFileAbsolute(kbd_path, .{ .read = true }) catch |err| @panic(@errorName(err));
    const stdio = osstd.fs.openFileAbsolute(stdio_path, .{ .read = true, .write = true }) catch |err| @panic(@errorName(err));

    kbd.close();
    stdio.close();

    osstd.debug.print("Exiting task...\n", .{});
    osstd.process.terminate_process(0);
}
