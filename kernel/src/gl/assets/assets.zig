const gl = @import("../gl.zig");

pub const fonts = [_][]const u8 {
    @embedFile("fonts/bitfont.bf"),
    @embedFile("fonts/monofont.bf"),
    //@embedFile("fonts/leickhable-monocle-16x24.bf"),
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

pub const palletes = [_][16]Color {
    .{ // VGA
        .{   0,   0,   0 }, // Black
        .{ 170,   0,   0 }, // Red
        .{   0, 170,   0 }, // Gren
        .{ 170,  85,   0 }, // Yellow
        .{   0,   0, 170 }, // Blue
        .{ 170,   0, 170 }, // Magenta
        .{   0, 170, 170 }, // Cyan
        .{ 170, 170, 170 }, // Light gray
        .{  85,  85,  85 }, // Dark gray
        .{ 255,  85,  85 }, // Bright Red
        .{  85, 255,  85 }, // Bright Green
        .{ 255, 255,  85 }, // Bright Yellow
        .{  85,  85, 255 }, // Bright Blue
        .{ 255,  85, 255 }, // Bright Magenta
        .{  85, 255, 255 }, // Bright Cyan
        .{ 255, 255, 255 }, // White
    },
    .{ // Dracula
        .{  40,  42,  54 }, // Black
        .{ 255,  85,  85 }, // Red
        .{  80, 250, 123 }, // Gren
        .{ 241, 250, 140 }, // Yellow
        .{  98, 114, 164 }, // Blue
        .{ 255,  85, 255 }, // Magenta
        .{ 139, 233, 253 }, // Cyan
        .{  78,  81, 100 }, // Light gray
        .{  68,  71,  90 }, // Dark gray

        .{ 255,  85,  85 }, // Bright Red
        .{  85, 255,  85 }, // Bright Green
        .{ 255, 255,  85 }, // Bright Yellow
        .{  85,  85, 255 }, // Bright Blue
        .{ 255,  85, 255 }, // Bright Magenta
        .{  85, 255, 255 }, // Bright Cyan
        .{ 248, 248, 242 }, // White
    },
};


const Color = struct { u8, u8, u8 };
