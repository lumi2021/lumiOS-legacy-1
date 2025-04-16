const std = @import("std");
const os = @import("root").os;
const fmt = std.fmt;
const uart = os.uart;
const gl = os.gl;

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

                const str = fmt.bufPrint(&buf, "[" ++ tag ++ " log] " ++ base ++ "\r\n", args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const warn = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Warn)) return;

                const str = fmt.bufPrint(&buf, "[" ++ tag ++ " warn] " ++ base ++ "\r\n", args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const dbg = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Debug)) return;

                const str = fmt.bufPrint(&buf, "[" ++ tag ++ " dbg] " ++ base ++ "\r\n", args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const err = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Error)) return;

                const str = fmt.bufPrint(&buf, "[" ++ tag ++ " error] " ++ base ++ "\r\n", args) catch unreachable;
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
    st.push(@src()); defer st.pop();
    
    history = String.init(os.memory.allocator);
    history_enabled = true;

    debug_win = gl.create_window(.text, 50, gl.canvasCharHeight - 10, true);
    gl.move_window(debug_win, 2, 2);
    gl.focus_window(debug_win);
}
pub fn add_to_history(str: []const u8) void {
    if (!history_enabled) return;
    st.push(@src()); defer st.pop();

    history_enabled = false;

    _ = history.writer().write(str) catch unreachable;

    update_debug_info();
    history_enabled = true;
}

fn update_debug_info() void {
    st.push(@src()); defer st.pop();

    const framebuffer_data = gl.get_buffer_info(debug_win);
    var fb = framebuffer_data.buf.char;

    // clean up
    for (0..framebuffer_data.height) |col| for (0..framebuffer_data.width) |row| {
        fb[row + col * framebuffer_data.width] = .char(' ');
    };

    // title
    fb[0] = .char('D');
    fb[1] = .char('E');
    fb[2] = .char('B');
    fb[3] = .char('U');
    fb[4] = .char('G');

    fb[6] = .char('L');
    fb[7] = .char('O');
    fb[8] = .char('G');
    fb[9] = .char(':');

    for (0..framebuffer_data.width) |x| fb[x + framebuffer_data.width] = .char(196);

    const sidx = getStartIndex(history.items, framebuffer_data.width, framebuffer_data.height - 3);
    const str = history.items[sidx..];

    var x: usize = 0;
    var y: usize = 0;

    for (str) |char| {
        if (char == '\n') { y += 1; x = 0; }
        else if (char < 32) continue
        else {
            fb[x + (y + 2) * framebuffer_data.width].value = char;
            x += 1;
            if (x >= framebuffer_data.width) { x = 0; y += 1; }
        }
    }

    gl.swap_buffer(debug_win);
}

// ChatGPT code idk what exactly it does
pub fn getStartIndex(s: []const u8, line_width: usize, max_lines: usize) usize {
    var total_lines: usize = 0;
    var line_start: usize = s.len;
    var i: usize = s.len;

    while (i > 0) {
        i -= 1;

        if (s[i] == '\n' or i == 0) {
            const real_start = if (s[i] == '\n') i + 1 else i;
            const line = s[real_start .. line_start];

            const len = line.len;
            const visuals = (len + line_width - 1) / line_width;

            total_lines += visuals;

            if (total_lines > max_lines) return real_start;

            line_start = i;
        }
    }

    return 0;
}
