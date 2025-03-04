const std = @import("std");
const gl = @import("../GL.zig");

const font_normal_bmp = @embedFile("../assets/BIOS.F08");
const char_normal_height = 8;
const font_big_bmp = @embedFile("../assets/AIXOID9.F20");
const char_big_height = 20;

pub var fg_color: u24 = 0xF8F8F2;
pub var bg_color: u24 = 0x282A36;

pub fn drawChar(c: u8, px: usize, py: usize) void {
    const char_begin = @as(usize, @intCast(c)) * char_normal_height;
    for (0 .. (char_normal_height * 2)) |y| {
        const line = font_normal_bmp[char_begin + y/2];

        for (0 .. 8) |x| {
            const pidx = (px + x) + (py + y) * gl.canvasPPS;
            if ((line & std.math.shl(u8, 1, 8 - x)) != 0) {
                gl.frameBuffer[pidx] = fg_color;
            }
        }
    }
}
pub fn drawCharBg(c: u8, px: usize, py: usize) void {
    const char_begin = @as(usize, @intCast(c)) * char_normal_height;
    for (0 .. (char_normal_height * 2)) |y| {
        const line = font_normal_bmp[char_begin + y/2];

        for (0 .. 9) |x| {
            const pidx = (px + x) + (py + y) * gl.canvasPPS;
            if ((line & std.math.shl(u8, 1, 8 - x)) != 0) {
                gl.frameBuffer[pidx] = fg_color;
            } else {
                gl.frameBuffer[pidx] = bg_color;
            }
        }
    }
}
pub fn drawBigChar(c: u8, px: usize, py: usize) void {
    const char_begin = @as(usize, @intCast(c)) * char_big_height;
    for (0 .. (char_big_height * 4)) |y| {
        const line = font_big_bmp[char_begin + y/4];

        for (0 .. (9 * 4)) |x| {
            const pidx = (px + x) + (py + y) * gl.canvasPPS;
            if ((line & std.math.shl(u8, 1, 8 - x/4)) != 0) {
                gl.frameBuffer[pidx] = fg_color;
            }
        }
    }

}

pub fn drawString(str: []const u8, px: usize, py: usize) void {
    var x = px;

    for (str) |i| {
        drawChar(i, x, py);
        x += 8;
    }
}
pub fn drawBigString(str: []const u8, px: usize, py: usize) void {
    var x = px;

    for (str) |i| {
        drawBigChar(i, x, py);
        x += 36;
    }
}
