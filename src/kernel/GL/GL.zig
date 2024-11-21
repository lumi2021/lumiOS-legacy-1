const std = @import("std");
const boot_info_data = @import("../structures/BootInfo.zig");

const font = @embedFile("../assets/40C-TYPE.F24");

var frameBuffer: []volatile u32 = undefined;
pub var framebuffer_data: *boot_info_data.FrameBuffer = undefined;


pub fn init(fb_data : *const boot_info_data.FrameBuffer) void {
    framebuffer_data = @constCast(fb_data);
    frameBuffer = @as([*]volatile u32, @ptrCast(@alignCast(fb_data.framebuffer)))[0 .. fb_data.size];
}

pub fn clear() void {
    for (0 .. framebuffer_data.width) |x| {
        for (0 .. framebuffer_data.height) |y| {
            frameBuffer[x + y * framebuffer_data.width] = @intCast(0x000055FF);
        }
    }
}

pub fn draw_rect(posx : usize, posy : usize, recwidth : usize, recheight : usize, color : u32) void {

    var x = posx;
    var y = posy;
    var width = recwidth;
    var height = recheight;

    if (x > framebuffer_data.width) {
        x = framebuffer_data.width;
        width = 0;
    }

    else if (y > framebuffer_data.height) {
        y = framebuffer_data.height;
        height = 0;
    }

    if (x + width > framebuffer_data.width) width = framebuffer_data.width - x;
    if (y + height > framebuffer_data.width) height = framebuffer_data.height - y;


    for (0 .. width) |w| {
        for (0 .. height) |h| {

            const index: usize = x + w + (h + y) * framebuffer_data.width;
            frameBuffer[index] = color;

        }
    }

}

pub fn draw_char(posx : usize, posy : usize, char: u8, color: u32) void {

    const glyph = font[@as(usize, char) * 24 .. @as(usize, char + 1) * 24];
    const scalex = 2;

    for (glyph, 0..) |col, col_i| {
        for (0..8 * scalex) |row| {
            
            if (col >> @truncate(8 - row/scalex) & 0x1 != 0)
            {
                const index = posx + row + (posy + col_i) * framebuffer_data.width;
                frameBuffer[index] = color;
            }
        }
    }

}

pub fn draw_string(posx : usize, posy : usize, string: []const u8, color: u32) void {

    var caret_pos_x : u32 = 0;
    var caret_pos_y : u32 = 0;

    for (string) |char| {

        const px = caret_pos_x * 17 + posx;
        const py = caret_pos_y * 25 + posy;

        draw_char(px, py, char, color);

        caret_pos_x += 1;
        caret_pos_y += 0;

    }
}
