const std = @import("std");
const os = @import("root").os;
const disk = os.drivers.disk;
const pci = os.drivers.pci;
const fs = os.fs;
const mem = os.memory;

const write = os.console_write("aHCI");
const st = os.stack_tracer;

const HBA_PxCMD_ST   = 0x0001;
const HBA_PxCMD_FRE  = 0x0010;
const HBA_PxCMD_FR   = 0x4000;
const HBA_PxCMD_CR   = 0x8000;

pub fn init_device(addr: pci.Addr) void {
    st.push(@src()); defer st.pop();

    const abar_addr = addr.barinfo(5).phy;
    const abar = os.memory.ptr_from_paddr(*HBARegisters, abar_addr);

    iterate_though_ports(abar);
}

pub fn read(device: *AHCIDeviceEntry, addr: u64, buffer: []u8) !void {
    st.push(@src()); defer st.pop();

    device.port.is = -1;
    const spin: u32 = 0; // Spin lock timeout counter
    const slot: u32 = find_cmdslot(device);
    if (slot == -1) return error.NoCmdSlot;
    
    const cmdheader: *HBACMDHeder = @intFromPtr(device.port.clb + @sizeOf(HBACMDHeder) * slot);

    _ = addr;
    _ = buffer;
    _ = spin;
    _ = cmdheader;
}

fn iterate_though_ports(abar: *HBARegisters) void {
    st.push(@src()); defer st.pop();

    // Search disk in implemented ports
    const pi = abar.pi;
    
    for (0 .. 32) |i| {
        if (pi & 1 != 0) {

            const dt = check_type(&abar.ports[i]);

            if (dt == .sata) {
                write.dbg("SATA found on port {}", .{i});

                const driveid = fs.get_free_drive_slot();
                
                const newDiskEntry: *disk.DiskEntry = mem.allocator.create(disk.DiskEntry) catch unreachable;
                newDiskEntry.* = .{
                    .index = driveid,
                    .data = .{ .sata = .{
                        .registers = abar,
                        .port = &abar.ports[i]
                    }}
                };
                
                fs.append_ahci_drive(newDiskEntry);
                disk.disk_list.append(newDiskEntry) catch unreachable;
            }
            else if (dt == .satapi) write.dbg("SATAPI found on port {}", .{i})
            else if (dt == .semb) write.dbg("SEMB found on port {}", .{i})
            else if (dt == .pm) write.dbg("PM found on port {}", .{i});
            //else write.dbg("No drive found on port {}", .{i});

        }
    }
}

fn port_rebase(abar: *HBARegisters, portno: usize) void {
    // TODO, not needing this rn
    _ = abar;
    _ = portno;
}

fn check_type(port: *HBAPort) AHCIDevice {
    st.push(@src()); defer st.pop();

    const ssts = port.ssts;
    const ipm = (ssts >> 8) & 0x0F;
    const det = ssts & 0x0F;

    if (det != 3) return ._null;
    if (ipm != 1) return ._null;

    return switch (port.sig) {
        0xEB140101 => .satapi,
        0xC33C0101 => .semb,
        0x96690101 => .pm,
        else => .sata
    };
}

// Find a free command list slot
fn find_cmdslot(device: AHCIDeviceEntry) u32 {
    st.push(@src()); defer st.pop();

    // If not set in SACT and CI, the slot is free
    var slots: u32 = (device.port.sact | device.port.ci);
    const cmdslots = (device.registers.cap & 0x1F) + 1;
    for (0..cmdslots) |i| {
        if ((slots & 1) == 0) return i;
        slots >>= 1;
    }
    return -1;
}

inline fn start_cmd(port: *HBAPort) void {
    st.push(@src()); defer st.pop();

    // Wait until CR (bit15) is cleared
    while (port.cmd & HBA_PxCMD_CR) {}
    // Set FRE (bit4) and ST (bit0)
    port.cmd |= HBA_PxCMD_FRE;
    port.cmd |= HBA_PxCMD_ST;
}
inline fn stop_cmd(port: *HBAPort) void {
    // Clear ST (bit0) and FRE (bit4)
    port.cmd &= ~@as(u32, HBA_PxCMD_ST);
    port.cmd &= ~@as(u32, HBA_PxCMD_FRE);

    // Wait until FR (bit14), CR (bit15) are cleared
    while ((port.cmd & HBA_PxCMD_FR) == 0 or (port.cmd & HBA_PxCMD_CR) == 0) {}
}

pub const HBARegisters = extern struct {
    cap: u32,
    ghc: u32,
    is: u32,
    pi: u32,
    vs: u32,
    ccc_ctl: u32,
    ccc_pts: u32,
    em_loc: u32,
    em_ctl: u32,
    cap2: u32,
    bohc: u32,
    _reserved_0: [0xA0 - 0x2C]u8,
    vendor: [0x100 - 0xA0]u8,

    ports: [32]HBAPort,
};

pub const HBAPort = extern struct {
    clb: u32, clbu: u32,
    fb: u32, fbu: u32,
    is: u32,
    ie: u32,
    cmd: u32,
    _reserved_0: u32,
    tfd: u32,
    sig: u32,
    ssts: u32,
    sctl: u32,
    serr: u32,
    sact: u32,
    ci: u32,
    sntf: u32,
    fbs: u32,
    _reserved_1: [11]u32,
    vendor: [4]u32,
};

const HBACMDHeder = packed struct {
    // DW0
    cfl: u5,  // Command FIS length in DWORDS, 2 ~ 16
    a: u1,    // ATAPI
    w: u1,    // Write, 1: H2D, 0: D2H
    p: u1,    // Prefetchable

    r: u1,    // Reset
    b: u1,    // BIST
    c: u1,    // Clear busy upon R_OK
    rsv0: u1, // Reserved
    pmp: u4,  // Port multiplier port

    prdtl: u16, // Physical region descriptor table length in entries

    // DW1
    prdbc: u32, // Physical region descriptor byte count transferred

    // DW2, DW3
    ctba: u32,  // Command table descriptor base address
    ctbau: u32, // Command table descriptor base address upper 32 bits

    // DW4 - DW7
    _rsv1: u128, // Reserved
};

pub const AHCIDevice = enum {
    _null,
    sata,
    semb,
    pm,
    satapi
};

pub const AHCIDeviceEntry = struct {
    registers: *HBARegisters,
    port: *HBAPort
};
