const std = @import("std");
const os = @import("root").os;
const port_io = os.port_io;
const pci = os.drivers.pci;
const vmm = os.memory.vmm;
const pmm = os.memory.pmm;
const paging = os.memory.paging;
const taskman = os.theading.taskManager;
const bf = os.utils.bitfields;

const write = os.console_write("eHCI");

pub fn register_device(device: pci.Addr) void {
    if (comptime (!os.config.input.usb2.enable)) {
        write.warn("USB3 input is disabled!", .{});
        return;
    }

    // TODO
    _ = device;
}
