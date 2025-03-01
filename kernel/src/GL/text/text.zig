const std = @import("std");
const gl = @import("../GL.zig");
const font_bmp = @embedFile("../assets/sysfont.F24");

pub var fg_color: u24 = 0xF8F8F2;
pub var bg_color: u24 = 0x282A36;

pub fn drawChar(c: u8, px: usize, py: usize) void {
    const char_height = 24;
    const char_begin = @as(usize, @intCast(c)) * char_height;

    for (0..char_height) |y| {
        const line = font_bmp[char_begin + y];

        for (0..8) |x| {
            const pidx = px + (x * 2) + (py + y) * gl.canvasPPS;
            if ((line & std.math.shl(u8, 1, 8 - x)) != 0) {
                gl.frameBuffer[pidx] = fg_color;
                gl.frameBuffer[pidx + 1] = fg_color;
            }
        }
    }

}
pub fn drawCharBg(c: u8, px: usize, py: usize) void {
    const char_height = 24;
    const char_begin = @as(usize, @intCast(c)) * char_height;

    for (0..char_height) |y| {
        const line = font_bmp[char_begin + y];

        for (0..8) |x| {
            const pidx = px + (x * 2) + (py + y) * gl.canvasPPS;
            if ((line & std.math.shl(u8, 1, 8 - x)) != 0) {
                gl.frameBuffer[pidx] = fg_color;
                gl.frameBuffer[pidx + 1] = fg_color;
            }
            else {
                gl.frameBuffer[pidx] = bg_color;
                gl.frameBuffer[pidx + 1] = bg_color;
            }
        }
    }

}
pub fn drawBigChar(c: u8, px: usize, py: usize) void {
    const char_height = 24;
    const char_begin = @as(usize, @intCast(c)) * char_height;

    for (0..char_height) |y| {
        const line = font_bmp[char_begin + y];

        for (0..8) |x| {
            const pidx = px + (x * 4) + (py + y * 2) * gl.canvasPPS;
            if ((line & std.math.shl(u8, 1, 8 - x)) != 0) {
                inline for (0..4)|i| {
                    gl.frameBuffer[pidx + i] = fg_color;
                    gl.frameBuffer[pidx + i + gl.canvasPPS] = fg_color;
                }
            }
        }
    }

}

pub fn drawString(str: []const u8, px: usize, py: usize) void {
    var x = px;

    for (str) |i| {
        drawChar(i, x, py);
        x += 16;
    }
}
pub fn drawBigString(str: []const u8, px: usize, py: usize) void {
    var x = px;

    for (str) |i| {
        drawBigChar(i, x, py);
        x += 32;
    }
}
