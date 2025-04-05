const std = @import("std");
const os = @import("root").os;
const gl = os.gl;
const osstd = @import("osstd");

const print = os.console_write("winman");
const st = os.stack_tracer;

pub fn init(_: ?*anyopaque) callconv(.C) isize {
    osstd.debug.print("Window Manager initialized!\n", .{});
    while (true) update_screen();
}

fn update_screen() void {
    const winlist = gl.window_list;

    for (0 .. winlist.len) |i| if (winlist[i]) |win| {
        
        const posx = @divFloor(gl.canvasCharWidth, 2) - @divFloor(win.width, 2);
        const posy = @divFloor(gl.canvasCharHeight, 2) - @divFloor(win.height, 2);

        for (0..win.width) |offset| {
            draw_char(posx + offset, posy);
            draw_char(posx + offset, posy + win.height);
        }
        for (0..(win.height+1)) |offset| {
            draw_char(posx, posy + offset);
            draw_char(posx + win.width, posy + offset);
        }
    };
}

inline fn draw_char(px: usize, py: usize) void {
    gl.draw_char(0, 'a', px, py);
}
