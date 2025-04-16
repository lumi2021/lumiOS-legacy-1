const std = @import("std");
const os = @import("root").os;
const port_io = os.port_io;
const pmm = os.memory.pmm;
const vmm = os.memory.vmm;

const bf = os.utils.bitfields;

const write = os.console_write("xHCI");

pub const CapRegs = extern struct {
    capabilites_length: u8,
    _res_01: u8,
    version: u16,
    hcs_params_1: u32,
    hcs_params_2: u32,
    hcs_params_3: u32,
    hcc_params_1: u32,

    doorbell_regs_bar_offset: u32,
    run_regs_bar_offset: u32,
    gccparams2: u32,
};
pub const OpRegs = extern struct {
    usbcmd: extern union {
        _raw: u32,

        run_not_stop: bf.Boolean(u32, 0),
        reset: bf.Boolean(u32, 1),
    },
    usbsts: extern union {
        _raw: u32,

        halted: bf.Boolean(u32, 0),
        controller_not_ready: bf.Boolean(u32, 11),
    },
    page_size: u32,
    _res_0C: [0x14 - 0x0C]u8,
    dnctrl: u32,
    crcr_low: extern union {
        _raw: u32,

        ring_cycle_state: bf.Boolean(u32, 0),
        command_stop: bf.Boolean(u32, 1),
        command_abort: bf.Boolean(u32, 2),
        command_ring_running: bf.Boolean(u32, 3),

        shifted_addr: bf.Bitfield(u32, 6, 32 - 6),
    },
    crcr_high: u32,
    _res_20: [0x30 - 0x20]u8,
    dcbaap_low: u32,
    dcbaap_high: u32,
    config: extern union {
        _raw: u32,

        max_slots_enabled: bf.Bitfield(u32, 0, 8),
    },
    _res_3C: [0x400 - 0x3C]u8,
    ports: [256]PortRegs,
};
pub const PortRegs = extern struct {
    portsc: u32,
    portpmsc: u32,
    portli: u32,
    reserved: u32,
};
pub const RunRegs = extern struct {
    microframe_idx: u32,
    _res_04: [0x20 - 0x4]u8,
    interrupt_regs: [1024]InterruptRegs,
};
pub const InterruptRegs = extern struct {
    iman: u32,
    imod: u32,
    erstsz: u32,
    res_0C: u32,
    erstba: u32,
    erdp: u32,
};
pub const Controller = struct {
    cap_regs: *volatile CapRegs,
    op_regs: *volatile OpRegs,
    run_regs: *volatile RunRegs,
    doorbells: *volatile [256]u32,
    context_size: usize = undefined,
    slots: []DeviceContext = undefined,
    commands: []CommandTRB = undefined,

    pub fn init(bar: usize) @This() {
        write.dbg("Initializing Controller...", .{});
        write.log("bar address: 0x{X}", .{bar});

        const cap_regs: *volatile CapRegs = @ptrFromInt(bar);

        var result = @This(){
            .cap_regs = cap_regs,
            .op_regs = @ptrFromInt(bar + cap_regs.capabilites_length),
            .run_regs = @ptrFromInt(bar + cap_regs.run_regs_bar_offset),
            .doorbells = @ptrFromInt(bar + cap_regs.doorbell_regs_bar_offset),
        };

        write.log("0b{b}", .{result.ports()[0].portsc});
        result.context_size = if ((result.cap_regs.hcc_params_1 & 1) == 1) 64 else 32;

        return result;
    }

    pub fn extcapsPtr(self: @This()) [*]volatile u32 {
        const off = (self.cap_regs.hcc_params_1 >> 16) & 0xFFFF;
        return @ptrFromInt(@intFromPtr(self.cap_regs) + @as(usize, off) * 4);
    }

    pub fn claim(self: @This()) void {
        var ext = self.extcapsPtr();

        while (true) {
            const ident = ext[0];

            if (ident == ~@as(u32, 0))
                break;

            if ((ident & 0xFF) == 0)
                break;

            if ((ident & 0xFF) == 1) {
                // Bios semaphore
                const bios_sem: *volatile u8 = @ptrFromInt(@intFromPtr(ext) + 2);
                const os_sem: *volatile u8 = @ptrFromInt(@intFromPtr(ext) + 3);

                if (bios_sem.* != 0) {
                    write.dbg("Controller is BIOS owned.", .{});
                    os_sem.* = 1;
                    // TODO scheduler yeld
                    //while (bios_sem.* != 0) os.thread.scheduler.yield();
                    write.dbg("Controller stolen from BIOS.", .{});
                }
            }
            
            const next_offset = (ident >> 8) & 0xFF;
            if (next_offset == 0) break;
            ext += next_offset;
        }
    }

    pub fn halted(self: @This()) bool {
        return self.op_regs.usbsts.halted.read();
    }

    pub fn halt(self: @This()) void {
        std.debug.assert(self.op_regs.usbcmd.run_not_stop.read());

        self.op_regs.usbcmd.run_not_stop.write(false);
        // TODO scheduler yeld
        //while (!self.halted()) os.thread.scheduler.yield();
    }

    pub fn start(self: @This()) void {
        std.debug.assert(self.halted());
        std.debug.assert(!self.op_regs.usbcmd.run_not_stop.read());

        self.op_regs.usbcmd.run_not_stop.write(true);
    }

    pub fn reset(self: @This()) void {
        if (!self.halted()) self.halt();

        self.op_regs.usbcmd.reset.write(true);
    }

    pub fn ready(self: @This()) bool {
        return !self.op_regs.usbsts.controller_not_ready.read();
    }

    pub fn waitReady(self: @This()) void {
        // TODO scheduler yeld
        //while (!self.ready()) os.thread.scheduler.yield();
        _ = self;
    }

    pub fn ports(self: @This()) []volatile PortRegs {
        const max_ports: u32 = (self.cap_regs.hcs_params_1 >> 24) & 0xFF;
        return self.op_regs.ports[0..max_ports];
    }
};
pub const DeviceContext = extern struct {
    slot: SlotContext,
    endpoint_slots: [31]EndpointContext,

    fn endpoints(self: *const @This()) []EndpointContext {
        return self.endpoint_slots[0 .. self.slot.off_0x00.context_entries.read() - 1];
    }
};
pub const SlotContext = extern struct {
    off_0x00: extern union {
        _raw: u32,

        route_string: bf.Bitfield(u32, 0, 20),
        speed: bf.Bitfield(u32, 20, 4),
        multi_tt: bf.Boolean(u32, 25),
        hub: bf.Boolean(u32, 26),
        context_entries: bf.Bitfield(u32, 27, 5),
    },
    off_0x04: extern union {
        _raw: u32,
    },
    off_0x08: extern union {
        _raw: u32,
    },
    off_0x0C: extern union {
        _raw: u32,
    },
    reserved_0x10: [0x10]u8,
};
pub const EndpointContext = extern struct {
    off_0x00: extern union {
        _raw: u32,
    },
    off_0x04: extern union {
        _raw: u32,
    },
    off_0x08: extern union {
        _raw: u32,
    },
    off_0x0C: extern union {
        _raw: u32,
    },
    off_0x10: extern union {
        _raw: u32,
    },
    reserved_0x14: [0x0C]u8,
};
pub const CommandTRB = extern struct {
    off_0x00: extern union {
        _raw: u32,
    },
    off_0x04: extern union {
        _raw: u32,
    },
    off_0x08: extern union {
        _raw: u32,
    },
    off_0x0C: extern union {
        _raw: u32,
    },
};
