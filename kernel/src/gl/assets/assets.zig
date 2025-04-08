const gl = @import("../gl.zig");
const Font = gl.Font;

pub const fonts = [_]Font {
    .{
        .width = 8, .height = 8,
        .scale = 1,
        .data = @embedFile("fonts/BIOS.F08")
    },
    .{
        .width = 8, .height = 20,
        .scale = 1,
        .data = @embedFile("fonts/AIXOID9.F20")
    },
    .{
        .width = 9, .height = 16,
        .scale = 1,
        .data = @embedFile("fonts/DOSJ-437.F16")
    },
    .{
        .width = 8, .height = 16,
        .scale = 1,
        .data = @embedFile("fonts/NORTON0.F16")
    },
    .{
        .width = 9, .height = 16,
        .scale = 1,
        .data = @embedFile("fonts/SCRAWL2.F16")
    },
    .{
        .width = 9, .height = 16,
        .scale = 1,
        .data = @embedFile("fonts/TANDY2K1.F16")
    },
    .{
        .width = 8, .height = 16,
        .scale = 1,
        .data = @embedFile("fonts/WACKY2.F16")
    },
};

pub const wallpapers = [_][]const u8 {
    @embedFile("wallpapers/dog.bm"),
    @embedFile("wallpapers/city.bm"),
    @embedFile("wallpapers/boobs.bm"),
    @embedFile("wallpapers/boobes.bm"),
    @embedFile("wallpapers/lilguy.bm"),
};
