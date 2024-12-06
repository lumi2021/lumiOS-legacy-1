const os = @import("root").os;

const write = os.console_write("Process A");

fn init() void {
    while (true) {
        write.log("Hello, World from process B!", .{});
    }
}
