const std = @import("std");
const os = @import("root").os;
const oslib = @import("oslib");

const write = os.console_write("Process A");
const mem = os.memory;

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    oslib.debug.print("Hello, World from process A!\n", .{});

    const path = std.fmt.allocPrintZ(mem.allocator, "/test", .{}) catch unreachable;
    const path2 = std.fmt.allocPrintZ(mem.allocator, "sys:/dev/", .{}) catch unreachable;
    
    oslib.debug.print("Trying to open \"{s}\" and \"{s}\"...\n", .{path, path2});

    const a = oslib.file.open(path, .{ .read = true });
    const b = oslib.file.open(path2, .{ .read = true });
    oslib.debug.print("File descriptors: {}, {}\n", .{a, b});

    oslib.debug.print("Closing files...\n", .{});
    oslib.file.close(a);
    oslib.file.close(b);

    oslib.debug.print("Terminating...\n", .{});
    oslib.process.terminate_process(2);
}
