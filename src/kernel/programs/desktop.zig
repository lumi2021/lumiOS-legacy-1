const std = @import("std");

const task_manager = @import("../task_manager.zig");
const GL = @import("../GL/GL.zig");
const os = @import("../OS/os.zig");

const write = @import("../IO/debug.zig").write("Process: Desktop");
const uart = @import("../IO/uart.zig");

pub fn init() void {
    write.log("The entry point of this process is ${X}!\r\n", .{@intFromPtr(&_main)});
    task_manager.create_task("Desktop", _main, .{}) catch write.err("error", .{});
}

pub fn _main() void {

    //uart.uart_puts("Hello, World!");
    write.log("Hello, World!", .{});

    GL.draw_rect(
       100, 100,
       os.boot_info.framebuffer.width - 200, os.boot_info.framebuffer.height - 200,
       0x004499
    );

    GL.draw_string(110, 110, "Hello_World!!", 0x000055FF);
    GL.draw_string(110, 140, "This is my OS!", 0x00000000);


    GL.draw_string(110, 170, "Developin this shit...", 0x00100000);

    var count: u64 = 0;
    while (true)
    {
        GL.draw_rect(
       110, 200,
       500, 30,
       0x004499
    );
        var buf: [16]u8 = undefined;
        const a = std.fmt.bufPrint(&buf, "{}", .{count}) catch unreachable;
        GL.draw_string(110, 200, a, 0x000055FF);
        count += 1;
    }

}