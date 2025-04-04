const os = @import("root").os;
const gl = os.gl;

pub const Pixel = gl.Pixel;
pub const VideoMode = gl.VideoMode;

pub const Win = extern struct {
    width: usize,
    height: usize,

    mode: VideoMode,

    swap: bool,
    buffer_0: packed union {
        char: [*]u8,
        pixel: [*]Pixel
    },
    buffer_1: packed union {
        char: [*]u8,
        pixel: [*]Pixel
    }
};
