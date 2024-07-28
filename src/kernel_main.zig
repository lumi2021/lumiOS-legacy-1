const std = @import("std");
const uefi = std.os.uefi;
const elf = std.elf;

const shared = @import("./util/shared/tables.zig");
const BootInfo = shared.BootInfo;
const FrameBuffer = shared.FrameBuffer;
const MemoryMapEntry = shared.MemoryMapEntry;

const font = @embedFile("./assets/40C-TYPE.F24");

var frameBuffer: []volatile u32 = undefined;
var fbInfo: FrameBuffer = undefined;


export fn _start(bootInfo: BootInfo) callconv(.C) noreturn {

    fbInfo = bootInfo.framebuffer;

    frameBuffer = @as([*]volatile u32, @ptrFromInt(fbInfo.baseAddress))[0 .. fbInfo.size / 4];

    //draw_clear_screen();
    //draw_rect(100, 100, fbInfo.width - 200, fbInfo.height - 200, 0x0055AA);

    //draw_string(110, 110, "Hello_World!!", 0x000055FF);

    //while(true) {}

    for (0..fbInfo.size) |i| {
        frameBuffer[i] = 0x0000FF00;
    }

    unreachable;

}


// Drawing functions

fn draw_clear_screen() void {

    for (0 .. fbInfo.width) |x|
    {
        for (0 .. fbInfo.height) |y|
        {
            frameBuffer[x + y * fbInfo.width] = @intCast(0x000055FF);
        }
    }

}

fn draw_rect(posx : usize, posy : usize, recwidth : usize, recheight : usize, color : u32) void {

    var x = posx;
    var y = posy;
    var width = recwidth;
    var height = recheight;

    if (x > fbInfo.width)
    {
        x = fbInfo.width;
        width = 0;
    }

    else if (y > fbInfo.height)
    {
        y = fbInfo.height;
        height = 0;
    }

    if (x + width > fbInfo.width) width = fbInfo.width - x;
    if (y + height > fbInfo.height) height = fbInfo.height - y;


    for (0 .. width) |w| {
        for (0 .. height) |h| {

            const index: usize = x + w + (h + y) * fbInfo.width;
            frameBuffer[index] = color;

        }
    }

}

fn draw_char(posx : usize, posy : usize, char: u8, color: u32) void {

    const glyph = font[@as(usize, char) * 24 .. @as(usize, char + 1) * 24];
    const scalex = 2;

    for (glyph, 0..) |col, col_i| {
        for (0..8 * scalex) |row| {
            
            if (col >> @truncate(8 - row/scalex) & 0x1 != 0)
            {
                const index = posx + row + (posy + col_i) * fbInfo.width;
                frameBuffer[index] = color;
            }
        }
    }

}

fn draw_string(posx : usize, posy : usize, string: []const u8, color: u32) void {

    var caret_pos_x = posx;
    var caret_pos_y = posy;

    for (string) |char| {

        const px = caret_pos_x * 17 + posx;
        const py = caret_pos_y * 25 + posx;

        draw_char(px, py, char, color);

        caret_pos_x += 1;
        caret_pos_y += 0;

    }

}
