const FrameBuffer = @import("../boot/boot_info.zig").FrameBuffer;

pub const text = @import("text/text.zig");
pub const image = @import("image/image.zig");

var framebuffer_data: FrameBuffer = undefined;
pub var frameBuffer: []u24 = undefined;

pub var canvasPPS: usize = 0;
pub var canvasWidth: usize = 0;
pub var canvasHeight: usize = 0;

pub var clear_color: u24 = 0x282A36;

pub fn init(fb: FrameBuffer) void {
    framebuffer_data = fb;
    const fb_ptr: [*]u24 = @ptrCast(@alignCast(fb.framebuffer));
    frameBuffer = fb_ptr[0..(fb.width * fb.height * fb.width)];

    canvasPPS = fb.pixels_per_scan_line;
    canvasWidth = fb.width;
    canvasHeight = fb.height;
}

pub fn clear() void {
    for (0..canvasWidth) |x| for (0..canvasHeight) |y| {
        const index = x + y * canvasWidth;
        frameBuffer[index] = clear_color;
    };
}
