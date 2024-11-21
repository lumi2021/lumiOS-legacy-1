const std = @import("std");
const GL = @import("./GL/GL.zig");
const os = @import("./OS/os.zig");
const builtin = std.builtin;
const kernel_setup = @import("./kernel_setup.zig");

comptime { _ = @import("boot/boot_entry.zig"); }

const write = @import("IO/debug.zig").write("Main");
const BootInfo = @import("./structures/BootInfo.zig").BootInfo;
const GDT = @import("./structures/GDT.zig").GDT;
const IDT = @import("./structures/IDT.zig").IDT;

pub fn main(bootloader_info: BootInfo) noreturn {
    asm volatile ("cli");

    write.log("Hello, World!", .{});

    os.boot_info = bootloader_info;

    kernel_setup.init_setup();

    write.log("Initing graphics lib...", .{});
    GL.init(&os.boot_info.framebuffer);
    GL.clear();

    write.log("Running standard processes...", .{});
    @import("programs/desktop.zig").init();

    write.log("Activating interruptions...", .{});
    asm volatile ("sti");

    while (true) {}

}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    _ = return_address;

    write.err("\n !!! Kernel Panic !!! \n", .{});
    write.err("{s}", .{msg});
    write.err("\n", .{});

    if (stack_trace) |trace| {
        write.log("Stack trace:", .{});
        _ = trace;
        write.log("\\\\TODO", .{});
    } else {
        write.log("No stack trace", .{});
    }

    while (true) {}
}
