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
    // const winlist = gl.window_list;

    // for (0 .. winlist.len) |i| if (winlist[i]) |win| {
        
    //     gl.swap_buffer(i);
    //     gl.redraw_screen_region(
    //         win.position_x,
    //         win.position_y,
    //         win.position_x + win.charWidth,
    //         win.position_y + win.charHeight
    //     );

    // };

    gl.redraw_screen_region(0, 0, 80, 50);
}
