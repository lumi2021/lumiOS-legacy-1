const os = @import("root").os;
const std = @import("std");

const print = os.console_write("keyboard_state");
const layout = @embedFile("layouts/pt-br_ABNT2.kbd");

const String = std.ArrayList(u8);
pub var text: String = undefined; 

var shift: bool = false;
var capitalize: bool = false;

pub fn init() void {
    text = String.init(os.memory.allocator);
}

pub fn logkey(scancode: u16) void {
    const pressed: bool = (scancode >> 7 & 1) == 0;

    // decoding the enum index
    var main_byte = scancode & 0x00FF;
    const secc_byte = scancode >> 8;

    if (!pressed) main_byte &= ~@as(u8, 0x80);
    if (secc_byte != 0) main_byte |= 1 << 8;
    if (secc_byte == 0xe1) main_byte |= 1 << 7;

    const keycode = layout[main_byte];

    const writer = text.writer();

    if (keycode == @intFromEnum(Keys.L_SHIFT) or keycode == @intFromEnum(Keys.R_SHIFT)) {
        shift = pressed;
        return;
    }

    if (pressed) {

        switch (keycode) {
            @intFromEnum(Keys.KEY_0) ... @intFromEnum(Keys.KEY_9)
                => writer.writeByte(if (!shift) ('0' + keycode - @intFromEnum(Keys.KEY_0))
                else num_symbols[keycode - @intFromEnum(Keys.KEY_0)]) catch unreachable,

            @intFromEnum(Keys.KEY_A) ... @intFromEnum(Keys.KEY_Z)
                => writer.writeByte(@as(u8, (if (capitalize or shift) 'A' else 'a'))
                + keycode - @intFromEnum(Keys.KEY_A)) catch unreachable,

            @intFromEnum(Keys.SPACE) => writer.writeByte(' ') catch unreachable,
            @intFromEnum(Keys.BACKSPACE) => _ = text.pop(),

            @intFromEnum(Keys.COMMA) => writer.writeByte(',') catch unreachable,
            @intFromEnum(Keys.DOT) => writer.writeByte('.') catch unreachable,

            // br-abnt2 only
            @intFromEnum(Keys.OEM_2) => writer.writeByte(':') catch unreachable,
            @intFromEnum(Keys.ABNT_C) => writer.writeByte('/') catch unreachable,

            @intFromEnum(Keys.CAPSLOCK) => capitalize = !capitalize,

            // invoke shell and clear buffer
            @intFromEnum(Keys.ENTER) => {
                const value = std.mem.trim(u8, text.items, " ");
                if (value.len != 0) os.shell.execute(value);
                text.clearAndFree();
            },

            @intFromEnum(Keys.F1) => os.fs.lsrecursive(),
            @intFromEnum(Keys.F2) => os.gl.toggle_z_buffer(),

            @intFromEnum(Keys.F11) => @import("../../../sysprocs/adam/adam.zig").reboot(),
            @intFromEnum(Keys.F12) => @import("../../../sysprocs/adam/adam.zig").shutdown(),

            else => print.warn("not handled keycode {s}", .{ @tagName(@as(Keys, @enumFromInt(keycode))) })
        }

    }

    os.debug_log.update_window();
}
pub const num_symbols = [_]u8 {')', '!', '@', '#', '$', '%', '"', '&', '*', '('};
pub const Keys = enum {
    _undefined,
    
    KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,

    KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J,
    KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T,
    KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z,

    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,

    ESC,
    TAB,
    SPACE,
    ENTER,
    CAPSLOCK,
    BACKSPACE,

    MINUS,
    EQUALS,
    COMMA,
    DOT,

    OEM_1,
    OEM_2,
    OEM_3,
    OEM_4,
    OEM_5,
    OEM_6,
    OEM_7,
    OEM_10,
    ABNT_C,

    L_SHIFT, R_SHIFT,
    L_CONTROL, R_CONTROL,
    L_SUPER, R_SUPER,
    L_MENU, R_MENU,

    APPS,

    PRINT_SCREEN,
    SCROLL_LOC,
    PAUSE,

    INSERT, DELETE,
    HOME, END,

    PG_UP, PG_DOWN,

    UP,
    LEFT,
    DOWN,
    RIGHT,
};
