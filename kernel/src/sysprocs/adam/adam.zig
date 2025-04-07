const std = @import("std");
const os = @import("root").os;
const osstd = @import("osstd");
const gl = os.gl;

const sysprocs = @import("../sysprocs.zig");

// Adam is a better term for the first father of all tasks
// than root was! - Terry A. Davis

var win: usize = undefined;

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    osstd.debug.print("Adam initialized\n", .{});

    osstd.debug.print("Initializing Window manager...\n", .{});
    _ = osstd.process.create_thead("winman", sysprocs.winman.init, null);

    osstd.debug.print("Initializing Adam window...\n", .{});
    win = gl.create_window(.text, 16, 18, true);
    gl.focus_window(win);

    osstd.debug.print("Drawing ascii...\n", .{});
    draw_ascii();

    while (true) {}
}

fn draw_ascii() void {
    const framebuffer_data = gl.get_buffer_info(win);
    var fb = framebuffer_data.buf.char;

    // clean up
    for (0..framebuffer_data.height) |col| for (0..framebuffer_data.width) |row| {
        fb[row + col * 16] = .char(' ');
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

    gl.swap_buffer(win);
}
