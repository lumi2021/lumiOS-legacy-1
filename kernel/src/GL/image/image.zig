const std = @import("std");
const gl = @import("../GL.zig");

pub fn drawImageRGBA(img: []const u8, width: usize, height: usize, x:usize, y: usize) void {

    for (0..width) |w| for (0..height) |h| {

        const img_idx = (w + h * width) * 4;
        if (img[img_idx + 3] == 0) continue;

        const color: u24 = @bitCast(img[img_idx..][0..3].*);
        
        const pixel_idx = (x + w) + (y + h) * gl.canvasWidth;
        gl.frameBuffer[pixel_idx] = color;

    };

}
