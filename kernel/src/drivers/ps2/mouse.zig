const os = @import("root").os;
const std = @import("std");

const ports = os.port_io;
const intman = os.system.interrupt_manager;
const IntFrame = os.theading.TaskContext;

const write = os.console_write("mouse");
const st = os.stack_tracer;

pub fn init() void {
    intman.interrupts[0x2C] = mouse_interrupt_handler;
}

fn mouse_interrupt_handler(_: *IntFrame) void {
    st.push(@src()); defer st.pop();

    if (ports.inb(0x64) & 1 != 0) {
        const data = ports.inb(0x60);

        write.dbg("mouse data received: {X}", .{data});
    }

    eoi();
}

inline fn eoi() void {
    ports.outb(0xA0, 0x20);
    ports.outb(0x20, 0x20);
}
