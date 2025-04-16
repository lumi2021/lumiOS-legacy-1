const std = @import("std");
const os = @import("root").os;
const port_io = os.port_io;
const pci = os.drivers.pci;
const structs = @import("xhci_structs.zig");
const vmm = os.memory.vmm;
const pmm = os.memory.pmm;
const paging = os.memory.paging;
const taskman = os.theading.taskManager;
const bf = os.utils.bitfields;

const DevicesList = std.ArrayList(*Device);
var devices_list: DevicesList = undefined;

const write = os.console_write("xHCI");

const Device = struct {
    device_addr: pci.Addr,
    controller: structs.Controller,
    task_id: usize,

    pub fn init(device: pci.Addr, controller: structs.Controller) *@This() {
        var newDevice = os.memory.allocator.create(Device) catch |err| @panic(@errorName(err));
        newDevice.device_addr = device;
        newDevice.controller = controller;

        return newDevice;
    }
};

pub fn init() void {
    devices_list = DevicesList.init(os.memory.allocator);
}

pub fn register_device(device: pci.Addr) void {
    if (comptime (!os.config.input.usb3.enable)) {
        write.warn("USB3 input is disabled!", .{});
        return;
    }

    write.dbg("Registring USB device...", .{});

    const barInfo = device.barinfo(0);
    const barInfoVirt = @intFromPtr(pmm.ptr_from_paddr(*volatile u8, barInfo.phy));

    paging.map_range(barInfo.phy, barInfoVirt, barInfo.size) catch @panic("error");

    const controller = structs.Controller.init(barInfoVirt);

    if ((controller.cap_regs.hcc_params_1 & 1) != 1)
        write.err("Controller not 64 bit compatible!", .{});

    write.log("creating task for controller...", .{});

    device.command().write(device.command().read() | 0x6);

    const newDevice = Device.init(device, controller);
    devices_list.append(newDevice) catch |err| @panic(@errorName(err));

    newDevice.task_id = taskman.run_process("xHCI device", controller_task, newDevice, @sizeOf(*Device))
    catch @panic("Cannot initialize task");
    write.log("usb device registred!", .{});
}

const write_device = os.console_write("USB Device");
fn controller_task(args: ?*anyopaque) callconv(.C) isize {
    write_device.dbg("Listening USB 3 port...", .{});

    const dev = @as(*Device, @alignCast(@ptrCast(args))).device_addr;
    const controller = @as(*Device, @alignCast(@ptrCast(args))).controller;

    _ = dev;
    _ = controller;

    while (true) {}
}
