const task_manager = @import("../task_manager.zig");
const GL = @import("../GL/GL.zig");
const os = @import("../OS/os.zig");
const dbg = @import("../IO/debug.zig");

pub fn init() void {
    dbg.printf("The entry point of this process is ${X}!\r\n", .{@intFromPtr(&_main)});
    task_manager.create_task("Desktop", _main);
}

pub fn _main() void {

    dbg.puts("Hello, World!");

    GL.draw_rect(
        100, 100,
        os.boot_info.framebuffer.width - 200, os.boot_info.framebuffer.height - 200,
        0x004499
    );

    GL.draw_string(110, 110, "Hello_World!!", 0x000055FF);
    GL.draw_string(110, 140, "This is my OS!", 0x00000000);

    while (true) {}

}