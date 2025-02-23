const std = @import("std");
const builtin = std.builtin;
pub const os = @import("os.zig");
const BootInfo = os.boot_info.BootInfo;

const sys = os.system;
const io = os.port_io;

pub var boot_info: BootInfo = undefined;

comptime {
    _ = @import("boot/boot_entry.zig");
}

const write = os.console_write("Main");
const st = os.stack_tracer;

pub fn main(binfo: BootInfo) noreturn {
    boot_info = binfo;

    st.push(@src());

    os.uart.uart_initialize();
    write.log("Hello, World from {s}!", .{@tagName(os.system.arch)});

    write.log("# Starting setup routine...", .{});
    sys.sys_flags.clear_interrupt();
    kernel_setup() catch |err| @panic(@errorName(err));

    write.log("# Starting system calls...", .{});
    try os.syscalls.init();

    write.log("# Starting drivers...", .{});
    os.drivers.init_all_drivers() catch |err| @panic(@errorName(err));

    //write.log("# Starting startup programs...", .{});
    os.theading.run_process(@constCast("Process A"), @import("test-processes/process_a.zig").init, null, 0) catch @panic("Cannot initialize process");
    //os.theading.run_process(@constCast("Process B"), @import("test-processes/process_b.zig").init, null, 0) catch @panic("Cannot initialize process");

    write.log("# Starting schedue...", .{});
    setup_pic();
    setup_timer();

    st.pop();
    write.log("halting init thread...", .{});

    while (true) sys.sys_flags.set_interrupt();
}

fn kernel_setup() !void {
    st.push(@src());
    defer st.pop();

    errdefer @panic("Error duting kernel sutupping...");

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
    os.theading.schedue.init();
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
    const panic_write = os.console_write("Panic");

    _ = return_address;
    _ = stack_trace;

    panic_write.err("\n !!! Kernel Panic !!! \n{s}\n", .{msg});

    const stk = st.get_stack_trace();

    if (stk.len < 1024) {
        panic_write.log("Stack Trace ({}):", .{ stk.len });

        for (stk) |i| {
            panic_write.log(" - {s}", .{i});
        }
    }

    os.theading.schedue.kill_current_process(-1);
    while (true) {}
}
