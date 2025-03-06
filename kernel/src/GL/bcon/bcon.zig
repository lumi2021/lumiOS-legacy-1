const std = @import("std");
const gl = @import("../GL.zig");
const text = gl.text;

var line: usize = 0;
var col: usize = 0;

fn getConHeight() usize { return @divFloor(gl.canvasHeight, 16) - 2; }
fn getConWidth() usize { return @divFloor(gl.canvasWidth, 8) - 2; }

pub fn printfc(comptime msg: []const u8, args: anytype, c: u24) void {
    const old_col = gl.text.fg_color;
    gl.text.fg_color = c;
    printf(msg, args);
    gl.text.fg_color = old_col;
}
pub fn printf(comptime msg: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    puts(std.fmt.bufPrint(&buf, msg, args) catch unreachable);
}
pub fn puts(msg: []const u8) void {
    if (!gl.ready) return;

    for (msg) |c| {
        if (c == '\n') {
            line += 1; if (line > getConHeight()) line = 0;
            col = 0;
        } else if (c == '\r') {
            col = 0;
        } else {
            const line_pixels = line * 16;
            const col_pixels = col * 8;
            gl.text.drawCharBg(c, col_pixels, line_pixels);
            col += 1; if (col > getConWidth()) {
                line += 1;
                col = 0;
            }
        }
    }

    var c = col;
    while (c < getConWidth()) : (c += 1) {
        const line_pixels = line * 16;
        const col_pixels = c * 8;
        gl.text.drawCharBg(' ', col_pixels, line_pixels);
    }

}
