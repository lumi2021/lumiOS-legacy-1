pub const pci = @import("pci/pci.zig");
pub const xhci = @import("usb/xhci.zig");
pub const ps2 = @import("ps2/ps2.zig");

pub const input_devices = .{
    .keyboard = &@import("ps2/keyboard.zig").kb_state,
};

const write = @import("root").os.console_write("Drivers");

pub fn init_all_drivers() !void {
    @import("ps2/keyboard.zig").init();

    write.log("## Initializing ps2...", .{});
    ps2.init();

    write.log("## Initializing pci...", .{});
    try pci.init();
}
