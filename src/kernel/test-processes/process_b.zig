const os = @import("root").os;

const write = os.console_write("Process B");

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    write.log("Hello, World from process B!", .{});

    for (0..8) |_| {
        do_process();
    }

    return 0;
}

var counting: u64 = 0;
pub fn do_process() void {
    write.log("Processing B... {}", .{counting});
    counting += 1;
}
