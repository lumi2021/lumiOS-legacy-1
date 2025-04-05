const gl = @import("../gl.zig");
const Font = gl.Font;

pub const fonts = [_]Font {
    .{
        .width = 8, .height = 8,
        .scale = 1,
        .data = @embedFile("BIOS.F08")
    },
    .{
        .width = 8, .height = 20,
        .scale = 1,
        .data = @embedFile("AIXOID9.F20")
    },
};
