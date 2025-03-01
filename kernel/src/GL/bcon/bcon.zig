const std = @import("std");
const gl = @import("../GL.zig");
const text = gl.text;

var line: usize = 0;
var col: usize = 0;

fn getConHeight() usize { return @divFloor(gl.canvasHeight, 24) - 2; }
fn getConWidth() usize { return @divFloor(gl.canvasWidth, 16) - 2; }

pub fn printf(comptime msg: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    puts(std.fmt.bufPrint(&buf, msg, args) catch unreachable);
}
pub fn puts(msg: []const u8) void {
    if (!gl.ready) return;

    gl.clearRect(0, line * 24, gl.canvasWidth, 48);

    for (msg) |c| {
        if (c == '\n') {
            line += 1; if (line > getConHeight()) line = 0;
            col = 0;
        } else if (c == '\r') {
            col = 0;
        } else if (c == 0) {
            break;
        } else {
            const line_pixels = line * 24;
            const col_pixels = col * 16;
            gl.text.drawCharBg(c, col_pixels, line_pixels);
            col += 1; if (col > getConWidth()) {
                line += 1;
                col = 0;
            }
        }
    }

}
