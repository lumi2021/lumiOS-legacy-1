const std = @import("std");
const os = @import("root").os;
const port_io = os.port_io;
const pci = os.drivers.pci;
const structs = @import("xhci_structs.zig");
const vmm = os.memory.vmm;
const pmm = os.memory.pmm;
const paging = os.memory.paging;
const task_manager = os.theading.schedue;
const bf = os.utils.bitfields;

const DevicesList = std.ArrayList(*Device);
var devices_list: DevicesList = undefined;

const write = os.console_write("xHCI");

const Device = struct {
    device_addr: pci.Addr,
    controller: structs.Controller,

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
    if (comptime (!os.config.input.usb.enable)) {
        write.warn("USB input is disabled!", .{});
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

    task_manager.run_process(@constCast("XHCI device"), controller_task, newDevice) catch write.err("error", .{});
    write.log("usb device registred!", .{});
}

const write_device = os.console_write("USB Device");
fn controller_task(args: ?*anyopaque) callconv(.C) isize {
    write_device.dbg("Task started...", .{});

    const dev = @as(*Device, @alignCast(@ptrCast(args))).device_addr;
    const controller_c = @as(*Device, @alignCast(@ptrCast(args))).controller;

    var controller = controller_c;
    write_device.dbg("Claiming controller...", .{});
    controller.claim();

    const usb3 = dev.read(u32, 0xDC);
    write_device.dbg("Switching usb3 ports: 0x{X}", .{usb3});
    dev.write(u32, 0xD8, usb3);

    const usb2 = dev.read(u32, 0xD4);
    write_device.dbg("Switching usb2 ports: 0x{X}", .{usb2});
    dev.write(u32, 0xD0, usb2);

    controller.reset();
    write_device.dbg("Controller reset", .{});

    controller.waitReady();
    write_device.dbg("Controller ready", .{});

    // TODO: Enable interrupts here

    { // Device context allocation
        const slots: u8 = @intCast(controller.cap_regs.hcs_params_1 & 0xF);
        controller.op_regs.config.max_slots_enabled.write(slots);
        write_device.dbg("Controller has {d} device context slots", .{slots});

        const context_bytes = @sizeOf(structs.DeviceContext) * @as(usize, slots);
        write_device.dbg("Allocationg {d} bytes for context", .{context_bytes});
        const mem = pmm.alloc(context_bytes) catch |err| @panic(@errorName(err));

        controller.op_regs.dcbaap_low = @truncate(mem);
        controller.op_regs.dcbaap_high = @intCast(mem >> 32);

        controller.slots = pmm.ptr_from_paddr([*]structs.DeviceContext, mem)[0..slots];

        for (controller.slots) |*slot| {
            slot.* = std.mem.zeroes(structs.DeviceContext);
        }
    }

    { // Command ring allocation
        const commands = 16;
        const mem = pmm.alloc(@sizeOf(structs.CommandTRB) * @as(usize, commands)) catch |err| @panic(@errorName(err));

        controller.op_regs.crcr_low._raw = @truncate(mem);
        controller.op_regs.crcr_high = @intCast(mem >> 32);

        controller.commands = pmm.ptr_from_paddr([*]structs.CommandTRB, mem)[0..commands];
        for (controller.commands) |*cmd| {
            cmd.* = std.mem.zeroes(structs.CommandTRB);
        }
    }

    controller.start();
    write_device.dbg("Controller started", .{});

    while (true) {}
    return 0;
}
