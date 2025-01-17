const os = @import("root").os;
const std = @import("std");

const ports = os.port_io;
const intman = os.system.interrupt_manager;
const IntFrame = os.theading.TaskContext;

const log = os.console_write("Keyboard");
const st = os.stack_tracer;

const KeyboardState = @import("keyboard/state.zig");

const kb = @import("keyboard/keyboard.zig");
var kb_state: kb.state.KeyboardState = .{ .layout = .en_US_QWERTY };

var keyboard_buffer_data: [8]u8 = undefined;
var keyboard_buffer_elements: usize = 0;

const Extendedness = enum {
    Extended,
    NotExtended,
};

pub fn init() void {
    intman.interrupts[0x21] = keyboard_interrupt_handler;
}

fn keyboard_interrupt_handler(_: *IntFrame) void {
    st.push(@src());
    defer st.pop();

    if (ports.inb(0x64) & 1 != 0) {
        const scancode = ports.inb(0x60);

        keyboard_buffer_data[keyboard_buffer_elements] = scancode;
        keyboard_buffer_elements += 1;

        kbEvent();
    }

    eoi();
}

const scancode_extended = 0xE0;

fn kbEvent() void {
    switch (keyboardBuffer()[0]) {
        0xE1 => {
            if (finishSequence(1, "\x1D\x45\xE1\x9D\xC5")) {
                kb_state.event(.press, .pause_break) catch return;
                kb_state.event(.release, .pause_break) catch return;
            }
        },
        scancode_extended => {
            if (keyboardBuffer().len < 2)
                return;

            switch (keyboardBuffer()[1]) {
                0x2A => {
                    if (finishSequence(2, &[_]u8{ scancode_extended, 0x37 })) {
                        kb_state.event(.press, .print_screen) catch return;
                    }
                },
                0xB7 => {
                    if (finishSequence(2, &[_]u8{ scancode_extended, 0xAA })) {
                        kb_state.event(.release, .print_screen) catch return;
                    }
                },
                else => {
                    standardKey(.Extended, keyboardBuffer()[1]);
                },
            }
        },
        else => {
            standardKey(.NotExtended, keyboardBuffer()[0]);
        },
    }
}

fn keyLocation(ext: Extendedness, scancode: u8) !kb.keys.Location {
    switch (ext) {
        .NotExtended => {
            return switch (scancode) {
                0x01 => .escape,
                0x02 => .number_key1,
                0x03 => .number_key2,
                0x04 => .number_key3,
                0x05 => .number_key4,
                0x06 => .number_key5,
                0x07 => .number_key6,
                0x08 => .number_key7,
                0x09 => .number_key8,
                0x0A => .number_key9,
                0x0B => .number_key0,
                0x0C => .right_of0,
                0x0D => .left_of_backspace,
                0x0E => .backspace,
                0x0F => .tab,
                0x10 => .line1_1,
                0x11 => .line1_2,
                0x12 => .line1_3,
                0x13 => .line1_4,
                0x14 => .line1_5,
                0x15 => .line1_6,
                0x16 => .line1_7,
                0x17 => .line1_8,
                0x18 => .line1_9,
                0x19 => .line1_10,
                0x1A => .line1_11,
                0x1B => .line1_12,
                0x1C => .enter,
                0x1D => .left_ctrl,
                0x1E => .line2_1,
                0x1F => .line2_2,
                0x20 => .line2_3,
                0x21 => .line2_4,
                0x22 => .line2_5,
                0x23 => .line2_6,
                0x24 => .line2_7,
                0x25 => .line2_8,
                0x26 => .line2_9,
                0x27 => .line2_10,
                0x28 => .line2_11,
                0x29 => .left_of1,
                0x2A => .left_shift,
                0x2B => .line2_12,
                0x2C => .line3_1,
                0x2D => .line3_2,
                0x2E => .line3_3,
                0x2F => .line3_4,
                0x30 => .line3_5,
                0x31 => .line3_6,
                0x32 => .line3_7,
                0x33 => .line3_8,
                0x34 => .line3_9,
                0x35 => .line3_10,
                0x36 => .right_shift,
                0x37 => .numpad_mul,
                0x38 => .left_alt,
                0x39 => .spacebar,
                0x3A => .capslock,
                0x3B => .f1,
                0x3C => .f2,
                0x3D => .f3,
                0x3E => .f4,
                0x3F => .f5,
                0x40 => .f6,
                0x41 => .f7,
                0x42 => .f8,
                0x43 => .f9,
                0x44 => .f10,
                0x45 => .numlock,
                0x46 => .scroll_lock,
                0x47 => .numpad7,
                0x48 => .numpad8,
                0x49 => .numpad9,
                0x4A => .numpad_sub,
                0x4B => .numpad4,
                0x4C => .numpad5,
                0x4D => .numpad6,
                0x4E => .numpad_add,
                0x4F => .numpad1,
                0x50 => .numpad2,
                0x51 => .numpad3,
                0x52 => .numpad0,
                0x53 => .numpad_point,

                0x56 => .right_of_left_shift,
                0x57 => .f11,
                0x58 => .f12,

                else => {
                    log.err("Unhandled scancode 0x{X}", .{scancode});
                    return error.UnknownScancode;
                },
            };
        },
        .Extended => {
            return switch (scancode) {
                0x10 => .media_rewind,
                0x19 => .media_forward,
                0x20 => .media_mute,
                0x1C => .numpad_enter,
                0x1D => .right_ctrl,
                0x22 => .media_pause_play,
                0x24 => .media_stop,
                0x2E => .media_volume_down,
                0x30 => .media_volume_up,
                0x35 => .numpad_div,
                0x38 => .right_alt,
                0x47 => .home,
                0x48 => .arrow_up,
                0x49 => .page_up,
                0x4B => .arrow_left,
                0x4D => .arrow_right,
                0x4F => .end,
                0x50 => .arrow_down,
                0x51 => .page_down,
                0x52 => .insert,
                0x53 => .delete,
                0x5B => .left_super,
                0x5C => .right_super,
                0x5D => .option_key,

                else => {
                    log.err("Unhandled extended scancode 0x{X}", .{scancode});
                    return error.UnknownScancode;
                },
            };
        },
    }
}

fn standardKey(ext: Extendedness, keycode: u8) void {
    defer keyboard_buffer_elements = 0;

    const loc = keyLocation(ext, keycode & 0x7F) catch return;
    kb_state.event(if (keycode & 0x80 != 0) .release else .press, loc) catch return;
}

inline fn eoi() void {
    ports.outb(0x20, 0x20);
}

fn keyboardBuffer() []const u8 {
    return keyboard_buffer_data[0..keyboard_buffer_elements];
}
fn finishSequence(offset: usize, seq: []const u8) bool {
    const buf = keyboardBuffer()[offset..];

    if (buf.len < seq.len)
        return false;

    if (std.mem.eql(u8, buf, seq)) {
        keyboard_buffer_elements = 0;
        return true;
    }

    @panic("Unexpected scancode sequence!");
}
