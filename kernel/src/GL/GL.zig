const FrameBuffer = @import("../boot/boot_info.zig").FrameBuffer;

var framebuffer_data: FrameBuffer = undefined;
var frameBuffer: []u24 = undefined;

var canvasPPS: usize = 0;
var canvasWidth: usize = 0;
var canvasHeight: usize = 0;

pub var clear_color: u24 = 0xFDFDFD;

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
