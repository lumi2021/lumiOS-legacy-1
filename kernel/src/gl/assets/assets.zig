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
        .width = 8, .height = 16,
        .scale = 1,
        .data = @embedFile("fonts/DOSJ-437.F16")
    },
    .{
        .width = 8, .height = 16,
        .scale = 1,
        .data = @embedFile("fonts/NORTON0.F16")
    },
    .{
        .width = 8, .height = 16,
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
    .{
        .width = 8, .height = 8,
        .scale = 1,
        .data = @embedFile("fonts/8X8ITAL.F08")
    },
    .{
        .width = 8, .height = 8,
        .scale = 1,
        .data = @embedFile("fonts/ATISMLW6.F08")
    },
    .{
        .width = 8, .height = 6,
        .scale = 1,
        .data = @embedFile("fonts/CM-4X6.F06")
    },
    .{
        .width = 8, .height = 8,
        .scale = 1,
        .data = @embedFile("fonts/EVXME94.F08")
    },
    .{
        .width = 8, .height = 8,
        .scale = 1,
        .data = @embedFile("fonts/HP-LX6.F08")
    },
    .{
        .width = 8, .height = 8,
        .scale = 1,
        .data = @embedFile("fonts/SCRIPT1.F08")
    },
};

pub const wallpapers = [_][]const u8 {
    @embedFile("wallpapers/dog.bm"),
    @embedFile("wallpapers/city.bm"),
    @embedFile("wallpapers/boobs.bm"),
    @embedFile("wallpapers/boobes.bm"),
    @embedFile("wallpapers/lilguy.bm"),
    @embedFile("wallpapers/cat.bm"),
    @embedFile("wallpapers/life.bm"),
};

pub const cursors = [_][]const u8 {
    @embedFile("cursor/cursor-white.bm"),
};
