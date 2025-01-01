const os = @import("root").os;

const write = os.console_write("Process A");

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    write.log("Hello, World from process A!", .{});
    while (true) {
        do_process();
    }

    return 0;
}

var counting: u64 = 0;
pub fn do_process() void {
    write.log("Processing A... {}", .{counting});
    counting += 1;

    write.log("Doing something...", .{});
    write.log("Something more...", .{});
    write.log("A bit more...", .{});
}
