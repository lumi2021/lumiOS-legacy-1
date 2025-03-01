const os = @import("root").os;
const FrameBuffer = @import("../boot/boot_info.zig").FrameBuffer;

pub const text = @import("text/text.zig");
pub const image = @import("image/image.zig");
pub const bcom = @import("bcon/bcon.zig");

var framebuffer_data: FrameBuffer = undefined;
pub var frameBuffer: []u32 = undefined;

pub var canvasPPS: usize = 0;
pub var canvasWidth: usize = 0;
pub var canvasHeight: usize = 0;
pub var canvasBPP: u8 = 0;
pub var ready = false;

pub var clear_color: u24 = 0x282A36;

pub const write = os.console_write("Graphics Lib");

pub fn init(fb: FrameBuffer) void {
    framebuffer_data = fb;
    const fb_ptr: [*]u32 = @ptrCast(@alignCast(fb.framebuffer));
    frameBuffer = fb_ptr[0..(fb.size / 4)];

    canvasPPS = fb.size / 4 / fb.height;
    canvasWidth = fb.width;
    canvasHeight = fb.height;
    canvasBPP = @intCast((fb.size * 8) / (canvasWidth * canvasHeight));

    write.log(\\
    \\fb size: {}
    \\pps: {}
    \\bpp: {}
    \\canvas width: {}
    \\canvas height: {}
    , .{ fb.size, canvasPPS, canvasBPP, canvasWidth, canvasHeight });

    ready = true;
}

pub fn clear() void {
    for (0..canvasWidth) |x| for (0..canvasHeight) |y| {
        const index = x + y * canvasPPS;
        frameBuffer[index] = clear_color;
    };
}
pub fn clearRect(ox: usize, oy: usize, w: usize, h: usize) void {
    for (ox..(ox + w)) |x| for (oy..(oy + h)) |y| {
        const index = x + y * canvasPPS;
        frameBuffer[index] = clear_color;
    };
}
