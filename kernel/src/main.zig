const std = @import("std");
const builtin = std.builtin;
pub const os = @import("os.zig");
const BootInfo = os.boot_info.BootInfo;
const sysprocs = @import("sysprocs/sysprocs.zig");

const sys = os.system;
const io = os.port_io;

pub var boot_info: BootInfo = undefined;

comptime {
    _ = @import("boot/boot_entry.zig");
}

const write = os.console_write("Main");
const st = os.stack_tracer;

pub fn main(binfo: BootInfo) noreturn {
    st.push(@src());

    boot_info = binfo;

    os.uart.uart_initialize();
    write.raw("Hello, World from {s}!\n", .{@tagName(os.system.arch)});

    write.log("# Starting setup routine...", .{});
    sys.sys_flags.clear_interrupt();
    kernel_setup();

    write.log("# Starting system calls...", .{});
    try os.syscalls.init();

    write.log("# Starting file systems...", .{});
    try os.fs.init();

    write.log("# Starting drivers...", .{});
    os.drivers.init_all_drivers() catch |err| @panic(@errorName(err));

    write.log("# Starting Video...", .{});
    {
        os.gl.init(binfo.framebuffer);

        const win_0 = os.gl.create_window(.graph, os.gl.canvasCharWidth, os.gl.canvasCharHeight, false);
        os.gl.focus_window(win_0);
        var screenbuf = os.gl.get_buffer_info(win_0);

        const wpp = os.gl.assets.wallpapers[5];

        const width = std.mem.readInt(u32, wpp[4..8], .big);
        const height = std.mem.readInt(u32, wpp[8..12], .big);
        
        const pixels: [*]os.gl.Pixel = @ptrCast(@alignCast(@constCast(wpp[16..].ptr)));

        for (0..screenbuf.width) |x| {
            for (0..screenbuf.height) |y| {

                const percent_x: f32 = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(screenbuf.width));
                const percent_y: f32 = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(screenbuf.height));
                const uv_x: usize = @intFromFloat(percent_x * width);
                const uv_y: usize = @intFromFloat(percent_y * height);

                const src = pixels[uv_x + uv_y * width];

                screenbuf.buf.pixel[x + y * screenbuf.width] = .rgb(src.blue, src.green, src.red);
            }
        }

        //const centerX = (os.GL.canvasWidth / 2 - (36 * 7) / 2);
        //const centerY = (os.GL.canvasHeight / 2 - 80 / 2);
        //const centerX2 = (os.GL.canvasWidth / 2 - (8 * 7) / 2);
        //const centerY2 = (os.GL.canvasHeight / 2 - 16 / 2);

        //os.GL.text.drawBigString("LUMI OS", centerX, centerY);
        //os.GL.text.drawString(" 0.1.0 ", centerX2, centerY2 + 40);

        os.gl.swap_buffer(win_0);
    }

    write.log("# Starting initialization programs...", .{});
    {
        _ = os.theading.run_process(@constCast("Adam"), sysprocs.adam.init, null, 0) catch @panic("Cannot initialize Adam");
    }

    os.fs.lsrecursive();

    write.log("# Starting schedue...", .{});
    setup_pic();
    setup_timer();

    st.pop();
    write.log("halting init thread...", .{});

    while (true) sys.sys_flags.set_interrupt();
}

fn kernel_setup() void {
    st.push(@src());
    defer st.pop();

    errdefer @panic("Error during kernel sutup!");

    write.log(" - Setting up global descriptor table...", .{});
    sys.global_descriptor_table.gdt_install();

    write.log(" - Setting up interrupt table...", .{});
    sys.interrupt_descriptor_table.idt_install();

    write.log(" - Setting up interrupts...", .{});
    sys.interrupt_manager.init();
    @import("interruptions.zig").init();

    write.log(" - Setting up memory handling...", .{});
    const features = os.memory.paging.enumerate_paging_features();
    os.memory.pmm.init(features.maxphyaddr, boot_info.memory_map);
    try os.memory.vmm.init(boot_info.memory_map);

    write.log(" - Setting up Task Manager...", .{});
    os.theading.taskManager.init();
}

fn setup_pic() void {
    st.push(@src());
    defer st.pop();

    io.outb(0x20, 0x11); // Send 0x11 (ICW1) to master PIC (port 0x20)
    io.outb(0xA0, 0x11); // Send 0x11 (ICW1) to slave  PIC (port 0xA0)

    io.outb(0x21, 0x20); // Configurate the master PIC interruption vector base (0x20)
    io.outb(0xA1, 0x28); // Configurate the slave  PIC interruption vector base (0x28)

    io.outb(0x21, 0x04); // Configurate the comunication line betwen master - slave PIC (IR2)
    io.outb(0xA1, 0x02); // PIC is on line 2

    io.outb(0x21, 0x01); // Enables 8086/88 (ICW4) in master PIC
    io.outb(0xA1, 0x01); // Enables 8086/88 (ICW4) in slave  PIC

    io.outb(0x21, 0x00); // Enables all interrupts from master PIC
    io.outb(0xA1, 0x00); // Enables all interrupts from slave  PIC
}

fn setup_timer() void {
    st.push(@src());
    defer st.pop();

    const frquency = 20;
    const divisor: u16 = 1193182 / frquency;

    io.outb(0x43, 0x36);
    io.outb(0x40, @intCast(divisor & 0xFF));
    io.outb(0x40, @intCast((divisor >> 8) & 0xFF));
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    _ = return_address;
    _ = stack_trace;

    write.err("\n!!! Kernel Panic !!!", .{});
    write.raw("Error message: {s}\r\n", .{msg});

    const stk = st.get_stack_trace();

    if (stk.len < 1024) {
        write.raw("Stack Trace ({}):\n", .{stk.len});
        for (stk) |i| {
            const it = i[0 .. std.mem.indexOf(u8, &i, "\x00") orelse 128];
            write.raw("   - {s}\n", .{it});
        }
    }

    os.theading.schedue.kill_current_process(-1);
    while (true) {}
}
