const std = @import("std");
const os = @import("root").os;
const oslib = @import("oslib");

const mem = os.memory;
const write = os.console_write("ProcessA");

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    write.log("Hello, World from process A!", .{});

    const path = std.fmt.allocPrintZ(mem.allocator, "/test", .{}) catch unreachable;
    const path2 = std.fmt.allocPrintZ(mem.allocator, "sys:/dev/", .{}) catch unreachable;
    
    write.log("Trying to open {s} and {s}...", .{path, path2});
    const a = oslib.file.open(path, .{ .read = true });
    const b = oslib.file.open(path2, .{ .read = true });
    write.log("$file descriptor: {}, {}\n", .{a, b});

    oslib.process.terminate_process(2);
}
