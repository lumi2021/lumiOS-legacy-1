const std = @import("std");
const os = @import("root").os;
const osstd = @import("osstd");

const write = os.console_write("Process A");
const mem = os.memory;

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    osstd.debug.print("Hello world from process A!", .{});

    while (true) {
        osstd.debug.print("tick!", .{});
        for (0 .. ~@as(usize, 0)) |_| std.mem.doNotOptimizeAway(asm volatile("nop"));
    }

    //const stdio_path = std.fmt.allocPrintZ(mem.allocator, "sys:/self/stdio", .{}) catch unreachable;

    //const stdio = osstd.fs.openFileAbsolute(stdio_path, .{ .read = true, .write = true })
    //    catch |err| { @panic(@errorName(err)); };

    //stdio.printf("Hello, World from process A!\n", .{}) catch unreachable;

    //kbd.close();
    //stdio.close();

    //osstd.debug.print("Exiting task...\n", .{});
    //osstd.process.terminate_process(0);
}
