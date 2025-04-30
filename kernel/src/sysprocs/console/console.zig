const std = @import("std");
const os = @import("root").os;
const gl = os.gl;
const osstd = @import("osstd");

const print = os.console_write("console");
var win: usize = undefined;

const String = std.ArrayList(u8);
var string_buffer: String = undefined;

pub fn init(_: ?*anyopaque) callconv(.C) isize {

    string_buffer = String.init(os.memory.allocator);
    _ = string_buffer.writer().write("adam > ") catch unreachable;

    osstd.debug.print("Creating window!\n", .{});
    win = gl.create_window(.text, (gl.canvasCharWidth / 2) - 8, gl.canvasCharHeight - 8, true);
    gl.move_window(win, (gl.canvasCharWidth / 2) + 4, 4);
    gl.focus_window(win);

    while (true) {
        update();
        render();
    }
}

fn update() void {
    
}

fn render() void {
    gl.swap_buffer(win);
}
