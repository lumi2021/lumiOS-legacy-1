const std = @import("std");
const os = @import("root").os;
const fmt = std.fmt;
const uart = os.uart;
const gl = os.gl;

const kbd_state = os.drivers.devices.keyboard.state;

const puts = uart.uart_puts;
const printf = uart.uart_printf;
const st = os.stack_tracer;

const String = std.ArrayList(u8);
pub var history: String = undefined;
pub var history_enabled: bool = false;
var debug_win: usize = undefined;

var buf: [1024]u8 = undefined;

pub fn write(comptime tag: []const u8) type {
    return struct {
        pub const log = struct {
            pub fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Log)) return;

                const str = fmt.bufPrint(&buf, "\x1b[030;107m[log " ++ tag ++ (" " ** (15 - tag.len)) ++ "]\x1b[0m  " ++ base ++ "\r\n", args) catch unreachable;

                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const warn = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Warn)) return;

                const str = fmt.bufPrint(&buf, "\x1b[047;030m[wrn " ++ tag ++ (" " ** (15 - tag.len)) ++ "]\x1b[0m  " ++ base ++ "\r\n", args) catch unreachable;

                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const dbg = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Debug)) return;

                const str = fmt.bufPrint(&buf, "\x1b[103;030m[dbg " ++ tag ++ (" " ** (15 - tag.len)) ++ "]\x1b[0m  " ++ base ++ "\r\n", args) catch unreachable;

                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const err = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Error)) return;

                const str = fmt.bufPrint(&buf, "\x1b[041;030m[err " ++ tag ++ (" " ** (15 - tag.len)) ++ " error]\x1b[0m  " ++ base ++ "\r\n", args) catch unreachable;

                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const raw = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                const str = fmt.bufPrint(&buf, base, args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const isModeEnabled = struct {
            pub inline fn f(mode: Mode) bool {
                return !isDisabled(tag, mode);
            }
        }.f;
    };
}

fn isDisabled(comptime tag: []const u8, comptime mode: Mode) bool {
    for (os.config.debug_ignore) |i|
        if (std.mem.eql(u8, tag, i.key) and (i.value & @intFromEnum(mode)) != 0) return true;
    return false;
}
const Mode = enum(u8) { Log = 0b0001, Error = 0b0010, Debug = 0b0100, Warn = 0b1000 };

pub fn create_history() !void {
    st.push(@src());
    defer st.pop();

    history = String.init(os.memory.allocator);
    history_enabled = true;

    debug_win = gl.create_window(.text, gl.canvasCharWidth - 16, gl.canvasCharHeight - 8, false);
    gl.move_window(debug_win, 8, 4);
    gl.focus_window(debug_win);
}
pub fn add_to_history(str: []const u8) void {
    if (!history_enabled) return;
    st.push(@src());
    defer st.pop();

    history_enabled = false;

    _ = history.writer().write(str) catch unreachable;

    update_window();
    history_enabled = true;
}
pub fn clear_history() void {
    history.clearRetainingCapacity();
}

pub fn update_window() void {
    st.push(@src());
    defer st.pop();

    const framebuffer_data = gl.get_buffer_info(debug_win);
    var fb = framebuffer_data.buf.char;

    // clean up
    for (0..framebuffer_data.height) |col| for (0..framebuffer_data.width) |row| {
        fb[row + col * framebuffer_data.width] = .char(' ');
    };

    // title
    fb[0] = .char('T');
    fb[1] = .char('e');
    fb[2] = .char('r');
    fb[3] = .char('m');
    fb[4] = .char('i');
    fb[5] = .char('n');
    fb[6] = .char('a');
    fb[7] = .char('l');
    fb[8] = .char(':');

    for (0..framebuffer_data.width) |i| fb[i + framebuffer_data.width] = .char(196);

    const sidx = getStartIndex(history.items, framebuffer_data.height - 3);
    const str = history.items[sidx..];

    var x: usize = 0;
    var y: usize = 0;

    const CharColor = gl.Char.CharColor;
    var foreground: CharColor = .white;
    var background: CharColor = .black;

    foreground = .white;
    background = .black;

    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        const char = str[i];

        if (char == 0x1b and str.len > i + 2 and str[i + 1] == '[') {
            var k: usize = i + 2;
            while (k < str.len and (std.ascii.isDigit(str[k]) or str[k] == ';')) : (k += 1) {}
            if (k == str.len) continue;

            var args_slice: []const u8 = str[i + 2 .. k];
            if (args_slice.len == 0) args_slice = "0";
            const action = str[k];

            const Args = std.ArrayList(usize);
            var args_list = Args.init(os.memory.allocator);
            var iterator = std.mem.splitAny(u8, args_slice, ";");

            var cur = iterator.next();
            while (cur != null) : (cur = iterator.next()) {
                args_list.append(if (cur.?.len == 0) 0 else std.fmt.parseUnsigned(usize, cur.?, 10) catch unreachable) catch unreachable;
            }

            const args = args_list.items;
            switch (action) {
                'm' => {
                    for (args) |value| {
                        switch (value) {
                            0 => {
                                foreground = .white;
                                background = .black;
                            },
                            30 => foreground = .black,
                            40 => background = .black,
                            31 => foreground = .red,
                            41 => background = .red,
                            32 => foreground = .green,
                            42 => background = .green,
                            33 => foreground = .yellow,
                            43 => background = .yellow,
                            34 => foreground = .blue,
                            44 => background = .blue,
                            35 => foreground = .magenta,
                            45 => background = .magenta,
                            36 => foreground = .cyan,
                            46 => background = .cyan,
                            37 => foreground = .light_gray,
                            47 => background = .light_gray,
                            90 => foreground = .dark_gray,
                            100 => background = .dark_gray,
                            91 => foreground = .bright_red,
                            101 => background = .bright_red,
                            92 => foreground = .bright_green,
                            102 => background = .bright_green,
                            93 => foreground = .bright_yellow,
                            103 => background = .bright_yellow,
                            94 => foreground = .bright_blue,
                            104 => background = .bright_blue,
                            95 => foreground = .bright_magenta,
                            105 => background = .bright_magenta,
                            96 => foreground = .bright_cyan,
                            106 => background = .bright_cyan,
                            97 => foreground = .white,
                            107 => background = .white,
                            else => {},
                        }
                    }
                },
                else => {},
            }

            args_list.deinit();

            i = k;
            continue;
        }

        if (char == '\n') {
            y += 1;
            x = 0;
        } else if (char == '\r') {
            x = 0;
        }

        //else if (char < 32) continue
        else {
            if (x <= framebuffer_data.width)
                fb[x + (y + 2) * framebuffer_data.width] = .charcol(char, foreground, background);
            x += 1;
        }
    }

    y += 2;
    fb[0 + framebuffer_data.width * y] = .char('@');
    fb[2 + framebuffer_data.width * y] = .char('a');
    fb[3 + framebuffer_data.width * y] = .char('d');
    fb[4 + framebuffer_data.width * y] = .char('a');
    fb[5 + framebuffer_data.width * y] = .char('m');
    fb[7 + framebuffer_data.width * y] = .char('>');

    x = 0;
    while (x < kbd_state.text.items.len) : (x += 1) {
        fb[9 + x + framebuffer_data.width * y] = .char(kbd_state.text.items[x]);
    }
    fb[9 + x + framebuffer_data.width * y] = .charcol('_', .light_gray, .black);

    gl.swap_buffer(debug_win);
}

// ChatGPT code idk what exactly it does
pub fn getStartIndex(input: []const u8, lines_visible: usize) usize {
    if (lines_visible == 0 or input.len == 0) return input.len;

    var count: usize = 0;
    var i: usize = input.len;

    while (i > 0) : (i -= 1) {
        if (input[i - 1] == '\n') {
            count += 1;
            if (count == lines_visible) {
                return i;
            }
        }
    }

    return 0;
}
