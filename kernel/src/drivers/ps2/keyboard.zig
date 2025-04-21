const os = @import("root").os;
const std = @import("std");

pub const state = os.drivers.devices.keyboard.state;

const ports = os.port_io;
const intman = os.system.interrupt_manager;
const IntFrame = os.theading.TaskContext;

const write = os.console_write("keyboard");
const st = os.stack_tracer;

var buffer: [2]u8 = .{0x00, 0x00};
var is_seccond_byte: bool = false;

pub fn init(ivector: usize) void {
    intman.interrupts[ivector] = keyboard_interrupt_handler;
}

fn keyboard_interrupt_handler(_: *IntFrame) void {
    st.push(@src()); defer st.pop();
    defer eoi();

    if (ports.inb(0x64) & 1 != 0) {
        const scancode = ports.inb(0x60);
  
        if (!is_seccond_byte and scancode == 0xE0 or scancode == 0xE1) {
            buffer[0] = scancode;
            is_seccond_byte = true;
            return;
        }
        else buffer[1] = scancode;

        write.dbg("{}", .{std.mem.readInt(u16, &buffer, .big)});
        state.logkey(std.mem.readInt(u16, &buffer, .big));
        buffer = .{0x00, 0x00};
        is_seccond_byte = false;
    }
}

inline fn eoi() void {
    ports.outb(0x20, 0x20);
}
