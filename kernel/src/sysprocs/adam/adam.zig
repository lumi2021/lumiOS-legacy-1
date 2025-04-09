const std = @import("std");
const os = @import("root").os;
const debug_log = os.debug_log;
const osstd = @import("osstd");
const gl = os.gl;

const sysprocs = @import("../sysprocs.zig");

// Adam is a better term for the first father of all tasks
// than root was! - Terry A. Davis

var ascii_win: usize = undefined;
var debug_win: usize = undefined;

var debug_ptr: usize = 0;

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    osstd.debug.print("Adam initialized\n", .{});

    osstd.debug.print("Initializing Window manager...\n", .{});
    _ = osstd.process.create_thead("winman", sysprocs.winman.init, null);

    osstd.debug.print("Initializing Adam windows...\n", .{});
    ascii_win = gl.create_window(.text, 16, 18, true);
    gl.focus_window(ascii_win);

    debug_win = gl.create_window(.text, 60, 80, true);
    gl.move_window(debug_win, 2, 2);
    gl.focus_window(debug_win);

    osstd.debug.print("Drawing ascii...\n", .{});
    draw_ascii();

    osstd.debug.print("Adam initialization routine complete.\n", .{});
    while (true) {

        if (debug_log.history.items.len > debug_ptr) {
            debug_ptr = debug_log.history.items.len;
            update_debug_info();
        }

    }
}

fn draw_ascii() void {
    const framebuffer_data = gl.get_buffer_info(ascii_win);
    var fb = framebuffer_data.buf.char;

    // clean up
    for (0..framebuffer_data.height) |col| for (0..framebuffer_data.width) |row| {
        fb[row + col * framebuffer_data.width] = .char(' ');
    };

    // title
    fb[0] = .char('A');
    fb[1] = .char('S');
    fb[2] = .char('C');
    fb[3] = .char('I');
    fb[4] = .char('I');

    fb[6] = .char('T');
    fb[7] = .char('A');
    fb[8] = .char('B');
    fb[9] = .char('L');
    fb[10] = .char('E');
    fb[11] = .char(':');

    for (0..16) |col| for (0..16) |row| {
        fb[row + (col + 2) * 16] = .char(@intCast(row + col * 16));
    };
    
    gl.swap_buffer(ascii_win);
}

fn update_debug_info() void {
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

    for (0 .. framebuffer_data.width) |x| {
        fb[x + framebuffer_data.width] = .char(196);
    }

    const fbh = framebuffer_data.height - 3;
    const entries_count = @min(fbh, debug_ptr);
    const entries_start = debug_ptr - entries_count;

    var i: usize = fbh - entries_count;

    while (i < fbh) : (i += 1) {
        const l = debug_log.history.items[entries_start + i];

        for (0 .. l.len) |x| {
            if (x >= framebuffer_data.width) break;
            if (l[x] < 32) continue;

            fb[x + (i+3) * framebuffer_data.width] = .char(l[x]);
        }
    }

    gl.swap_buffer(debug_win);
}
