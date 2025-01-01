const std = @import("std");
const builtin = std.builtin;
pub const os = @import("os.zig");
const BootInfo = os.boot_info.BootInfo;

const sys = os.system;

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

    write.log("# Starting PCI...", .{});
    os.drivers.pci.init() catch |err| @panic(@errorName(err));

    //write.log("# Starting startup programs...", .{});
    //os.theading.run_process(@constCast("Process A"), @import("test-processes/process_a.zig").init, null) catch @panic("Cannot initialize process");
    //os.theading.run_process(@constCast("Process B"), @import("test-processes/process_b.zig").init, null) catch @panic("Cannot initialize process");

    write.log("# Starting schedue...", .{});
    set_timer();

    st.pop();
    write.log("halting init thread...", .{});
    while (true) sys.sys_flags.set_interrupt();
}

fn kernel_setup() !void {
    st.push(@src());

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

    st.pop();
}

fn set_timer() void {
    st.push(@src());

    const io = os.port_io;

    io.outb(0x20, 0x11);
    io.outb(0xA0, 0x11);

    io.outb(0x21, 0x20);
    io.outb(0xA1, 0x28);

    io.outb(0x21, 0x04);
    io.outb(0xA1, 0x02);

    io.outb(0x21, 0x01);
    io.outb(0xA1, 0x01);

    io.outb(0x21, 0x0);
    io.outb(0xA1, 0x0);

    const frquency = 20;
    const divisor: u16 = 1193182 / frquency;

    io.outb(0x43, 0x36);
    io.outb(0x40, @intCast(divisor & 0xFF));
    io.outb(0x40, @intCast((divisor >> 8) & 0xFF));

    st.pop();
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    const panic_write = os.console_write("Panic");

    _ = return_address;
    _ = stack_trace;

    panic_write.err("\n !!! Kernel Panic !!! \n{s}\n", .{msg});

    const stk = st.get_stack_trace();

    if (stk.len < 1024) {
        panic_write.log("Stack Trace:", .{});

        for (stk) |i| {
            panic_write.log("- {s}", .{i});
        }
    } else {
        panic_write.log("last 5:", .{});
        for ((1024 - 5)..stk.len) |i| {
            panic_write.log("- {s}", .{stk[i]});
        }
    }

    os.theading.schedue.kill_current_process();
    while (true) {}
}
