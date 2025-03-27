const fb = @import("Framebuffer.zig");
const tb = @import("Textbuffer.zig");

pub const content: *ContenType = &__internal_content__;
var __internal_content__: ContenType = undefined;

pub fn Init() @This() {
    var newWin = @This(){};
    newWin.__internal_content__ = .{ .unitialized = undefined };
}

const ContenType = union {
    unitialized: void,
    frame: fb,
    text: tb
};
