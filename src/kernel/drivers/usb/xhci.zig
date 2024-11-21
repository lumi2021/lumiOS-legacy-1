const std = @import("std");
const port_io = @import("../../IO/port_io.zig");
const pci = @import("../pci/pci.zig");
const structs = @import("xhci_structs.zig");

const vmm = @import("../../memory/vmm.zig");
const pmm = @import("../../memory/pmm.zig");

const task_manager = @import("../../task_manager.zig");

const bf = @import("../../utils/bitfields.zig");

const write = @import("../../IO/debug.zig").write("xHCI");

pub fn registerDevice(device: pci.Addr) void {
    write.dbg("Registring USB device...", .{});

    const barInfo = device.barinfo(0);
    const barInfoVirt = @intFromPtr(pmm.ptr_from_physaddr(*volatile u8, barInfo.phy));

    vmm.map_section(barInfo.phy, barInfoVirt, barInfo.size) catch @panic("error");

    const controller = structs.Controller.init(barInfoVirt);

    if ((controller.cap_regs.hcc_params_1 & 1) != 1)
        write.err("Controller not 64 bit compatible!", .{});
    
    device.command().write(device.command().read() | 0x6);
    task_manager.create_task("XHCI device", controllerTask, .{device, controller}) catch write.err("error", .{});

    write.log("usb device registred!", .{});   
}

fn controllerTask(dev: pci.Addr, controller_c: structs.Controller) !void {
    var controller = controller_c;
    controller.claim();

    const usb3 = dev.read(u32, 0xDC);
    write.dbg("Switching usb3 ports: 0x{X}", .{usb3});
    dev.write(u32, 0xD8, usb3);

    const usb2 = dev.read(u32, 0xD4);
    write.dbg("Switching usb2 ports: 0x{X}", .{usb2});
    dev.write(u32, 0xD0, usb2);

    controller.reset();
    write.dbg("Controller reset", .{});

    controller.waitReady();
    write.dbg("Controller ready", .{});

    // TODO: Enable interrupts here

    { // Device context allocation
        const slots: u8 = @intCast(controller.cap_regs.hcs_params_1 & 0xF);
        controller.op_regs.config.max_slots_enabled.write(slots);
        write.dbg("Controller has {d} device context slots", .{slots});

        const context_bytes = @sizeOf(structs.DeviceContext) * @as(usize, slots);
        const mem = try pmm.alloc(context_bytes);

        controller.op_regs.dcbaap_low = @truncate(mem);
        controller.op_regs.dcbaap_high = @intCast(mem >> 32);

        controller.slots = pmm.ptr_from_physaddr([*]structs.DeviceContext, mem)[0..slots];

        for (controller.slots) |*slot| {
            slot.* = std.mem.zeroes(structs.DeviceContext);
        }
    }

    { // Command ring allocation
        const commands = 16;
        const mem = try pmm.alloc(@sizeOf(structs.CommandTRB) * @as(usize, commands));

        controller.op_regs.crcr_low._raw = @truncate(mem);
        controller.op_regs.crcr_high = @intCast(mem >> 32);

        controller.commands = pmm.ptr_from_physaddr([*]structs.CommandTRB, mem)[0..commands];
        for (controller.commands) |*cmd| {
            cmd.* = std.mem.zeroes(structs.CommandTRB);
        }
    }

    controller.start();
    write.dbg("Controller started", .{});
}
