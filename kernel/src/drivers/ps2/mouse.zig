const os = @import("root").os;
const std = @import("std");
const devices = os.drivers.devices;

pub const state = devices.mouse.state;

const ports = os.port_io;
const intman = os.system.interrupt_manager;
const IntFrame = os.theading.TaskContext;

const write = os.console_write("mouse");
const st = os.stack_tracer;

var packageBuf: [3]u8 = undefined;
var packageCount: usize = 0;

pub fn init() void {
    intman.interrupts[0x2C] = mouse_interrupt_handler;
}

fn mouse_interrupt_handler(_: *IntFrame) void {
    st.push(@src()); defer st.pop();

    if (ports.inb(0x64) & 1 != 0) {
        packageBuf[packageCount] = ports.inb(0x60);
        
        if (packageCount >= 2) {
            interpret_data();
            packageCount = 0;
        } else if (packageCount == 0 and ((packageBuf[0] & 0x08) == 0)) packageCount = 0
        else packageCount += 1;
    }

    eoi();
}

fn interpret_data() void {
    st.push(@src()); defer st.pop();

    const buttons: Buttons = @bitCast(packageBuf[0]);
    const movx: i8 = @bitCast(packageBuf[1]);
    const movy: i8 = @bitCast(packageBuf[2]);

    state.set_button(.left, buttons.left_button);
    state.set_button(.middle, buttons.middle_button);
    state.set_button(.right, buttons.right_button);

    state.move_delta(movx, -movy);
    state.commit();

}

inline fn eoi() void {
    ports.outb(0xA0, 0x20);
    ports.outb(0x20, 0x20);
}

const Buttons = packed struct(u8) {
    left_button: bool,
    right_button: bool,
    middle_button: bool,

    _: u1,

    x_axis_sign_bit: u1,
    y_axis_sign_bit: u1,

    x_overflow: bool,
    y_overflow: bool
};
