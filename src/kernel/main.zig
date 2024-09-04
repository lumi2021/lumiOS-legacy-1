const std = @import("std");
const GL = @import("./GL/GL.zig");
const os = @import("./OS/os.zig");
const dbg = @import("./IO/debug.zig");
const builtin = std.builtin;
const kernel_setup = @import("./kernel_setup.zig");

const BootInfo = @import("./structures/BootInfo.zig").BootInfo;
const GDT = @import("./structures/GDT.zig").GDT;
const IDT = @import("./structures/IDT.zig").IDT;

export fn _start(bootloader_info: BootInfo) callconv(.SysV) noreturn {

    asm volatile ("cli");

    os.boot_info = bootloader_info;

    kernel_setup.init_setup();

    dbg.puts("Initing graphics lib...\n");
    GL.init(&os.boot_info.framebuffer);
    GL.clear();

    dbg.puts("Running default processes...\n");
    @import("programs/desktop.zig").init();

    dbg.puts("Activating interruptions...\n");
    asm volatile ("sti");

    while (true) {}

}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    _ = return_address;

    dbg.puts("\n !!! Kernel Panic !!! \n");
    dbg.puts(msg);
    dbg.puts("\n");

    if (stack_trace) |trace| {
        dbg.puts("Stack trace:");
        _ = trace;
        dbg.puts("\\\\TODO");
    } else {
        dbg.puts("No stack trace");
    }

    while (true) {}
}
