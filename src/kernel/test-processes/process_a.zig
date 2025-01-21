const os = @import("root").os;
const oslib = @import("oslib");

const write = os.console_write("ProcessA");

pub fn init(_: ?*anyopaque) callconv(.C) isize {

    write.log("Hello, World from process A!", .{});

    _ = oslib.raw_system_call(0, 0, 0, 0, 0);
    //_ = oslib.raw_system_call(1, 0, 0, 0, 0);

    return 0;
}