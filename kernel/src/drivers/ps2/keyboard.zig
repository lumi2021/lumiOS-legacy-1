const os = @import("root").os;
const std = @import("std");

const ports = os.port_io;
const intman = os.system.interrupt_manager;
const IntFrame = os.theading.TaskContext;

const write = os.console_write("keyboard");
const st = os.stack_tracer;

pub fn init() void {
    intman.interrupts[0x21] = keyboard_interrupt_handler;
}

fn keyboard_interrupt_handler(_: *IntFrame) void {
    st.push(@src()); defer st.pop();

    if (ports.inb(0x64) & 1 != 0) {
        const scancode = ports.inb(0x60);

        write.dbg("keyboard data received: {X}", .{scancode});
    }

    eoi();
}

inline fn eoi() void {
    ports.outb(0x20, 0x20);
}
