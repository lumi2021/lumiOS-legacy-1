pub const keyboard = @import("keyboard/keyboard.zig");
pub const mouse = @import("mouse/mouse.zig");

pub fn init_devices() void {
    keyboard.state.init();
    mouse.state.init();
}
