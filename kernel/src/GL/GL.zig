const std = @import("std");
const os = @import("root").os;
const FrameBuffer = @import("../boot/boot_info.zig").FrameBuffer;

var framebuffer_data: FrameBuffer = undefined;
pub var frameBuffer: []u32 = undefined;

pub var canvasPPS: usize = 0;
pub var canvasWidth: usize = 0;
pub var canvasHeight: usize = 0;
pub var canvasBPP: u8 = 0;
pub var ready = false;

pub var clear_color: u24 = 0x0; // 0x282A36;

const write = os.console_write("Graphics Lib");
const st = os.stack_tracer;

pub fn init(fb: FrameBuffer) void {
    st.push(@src()); defer st.pop();

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


// Clears all the screen to the configurated clear color
pub fn clear() void {
    for (0..canvasWidth) |x| for (0..canvasHeight) |y| {
        const index = x + y * canvasPPS;
        frameBuffer[index] = clear_color;
    };
}