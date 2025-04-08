pub const os = @import("root").os;
pub const gl = os.gl;

pub var position: Point = undefined;
pub var bounds: Point = undefined;

pub var buttons: [5]bool = undefined;

pub fn init() void {
    @memset(buttons, false);
    
}

pub inline fn set_button(button: Button, value: bool) void {
    buttons[@intFromEnum(button)] = value;
}
pub inline fn get_button(button: Button) bool {
    return buttons[@intFromEnum(button)];
}
pub fn move_delta(x: usize, y: usize) void {
    position.positionX += x;
    position.positionY += y;
}

pub fn commit() void {
    // TODO
}


pub const Point = struct { positionX: usize, positionY: usize };
pub const Button = enum(u8) {
    left = 0,
    right = 1,
    middle = 2
};
