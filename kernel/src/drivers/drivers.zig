pub const pci = @import("pci/pci.zig");
pub const xhci = @import("usb/xhci.zig");
pub const ps2 = @import("ps2/ps2.zig");
pub const disk = @import("disk//disk.zig");

pub const devices = @import("devices/devices.zig");

const write = @import("root").os.console_write("drivers");

pub fn init_all_drivers() !void {
    devices.init_devices();

    write.log("## Initializing disk...", .{});
    disk.init();

    write.log("## Initializing ps2...", .{});
    ps2.init();
    write.log("## Initializing xHCI...", .{});
    xhci.init();

    // PCI must be initialized after everything as
    // it will feed the devies for the other drivers
    // during initialization.
    write.log("## Initializing pci...", .{});
    try pci.init();
}
