const os = @import("root").os;
const gl = os.gl;

pub const Pixel = gl.Pixel;
pub const Char = gl.Char;
pub const VideoMode = gl.VideoMode;

pub const Win = struct {
    position_x: isize,
    position_y: isize,

    charWidth: usize,
    charHeight: usize,
    pixelWidth: usize,
    pixelHeight: usize,

    hasBorder: bool,

    mode: VideoMode,

    swap: bool,
    buffer_0: Framebuffer,
    buffer_1: Framebuffer,

    pub const Framebuffer = packed union {
        char: [*]Char,
        pixel: [*]Pixel
    };
};
