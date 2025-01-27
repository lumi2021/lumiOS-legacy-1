const os = @import("root").os;
const oslib = @import("oslib");

const write = os.console_write("ProcessA");

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    write.log("Hello, World from process A!", .{});

    const a = oslib.raw_system_call(1, 0, 0, 0, 0);
    write.log("${X:0>16}\n", .{a});

    oslib.process.terminate_process(2);
}
