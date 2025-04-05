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

    for (1 .. winlist.len) |i| if (winlist[i]) |win| {
        
        const posx = @divFloor(gl.canvasCharWidth, 2) - @divFloor(win.charWidth, 2);
        const posy = @divFloor(gl.canvasCharHeight, 2) - @divFloor(win.charHeight, 2);

        gl.swap_buffer(0);
        gl.redraw_screen_region(
            posx,
            posy,
            posx + win.charWidth + 1,
            posy + win.charHeight + 1
        );

    };
}
