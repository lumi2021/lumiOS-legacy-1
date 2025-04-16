const std = @import("std");
const os = @import("root").os;
const debug_log = os.debug_log;
const osstd = @import("osstd");
const gl = os.gl;

const sysprocs = @import("../sysprocs.zig");

const print = os.console_write("Adam");

// Adam is a better term for the first father of all tasks
// than root was! - Terry A. Davis

var ascii_win: usize = undefined;
var debug_win: usize = undefined;

var debug_ptr: usize = 0;

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    osstd.debug.print("Adam initialized\n", .{});

    print.log("# Initializing drivers...", .{});
    _ = osstd.process.create_thead("adam branch", init_all_drivers_async, null);

    osstd.debug.print("# Initializing Window manager...\n", .{});
    _ = osstd.process.create_thead("winman", sysprocs.winman.init, null);

    osstd.debug.print("Initializing Adam window...\n", .{});
    ascii_win = gl.create_window(.text, 16, 18, true);
    gl.focus_window(ascii_win);

    osstd.debug.print("Drawing ascii...\n", .{});
    draw_ascii();

    osstd.debug.print("Adam initialization routine complete.\n", .{});
    while (true) {
    }
}

pub fn init_all_drivers_async(_: ?*anyopaque) callconv(.C) isize {
    os.drivers.init_all_drivers() catch |err| @panic(@errorName(err));
    return 0;
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
