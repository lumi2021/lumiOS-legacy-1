const gl = @import("../gl.zig");

pub const fonts = [_][]const u8 {
    @embedFile("fonts/bitfont.bf"),
    @embedFile("fonts/monofont.bf"),
    @embedFile("fonts/guifont.bf"),
};

pub const wallpapers = [_][]const u8 {
    @embedFile("wallpapers/dog.bm"),
    @embedFile("wallpapers/city.bm"),
    @embedFile("wallpapers/lilguy.bm"),
    @embedFile("wallpapers/cat.bm"),
    @embedFile("wallpapers/life.bm"),
    @embedFile("wallpapers/god.bm"),
};

pub const cursors = [_][]const u8 {
    @embedFile("cursor/cursor-white.bm"),
};
