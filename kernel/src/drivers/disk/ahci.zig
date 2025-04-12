const std = @import("std");
const os = @import("root").os;
const disk = os.drivers.disk;
const pci = os.drivers.pci;
const fs = os.fs;
const mem = os.memory;

const write = os.console_write("aHCI");
const st = os.stack_tracer;

pub fn init_device(addr: pci.Addr) void {
    st.push(@src()); defer st.pop();

    write.log("Trying to initialize device...", .{});

    const abar_phys: usize = os.memory.vaddr_from_paddr(addr.barinfo(5).phy);
    const abar: *HBAMem = @ptrFromInt(abar_phys);

    iterate_ports(abar);
}

pub fn read(device: AHCIDeviceEntry, sector: u64, buffer: []u8) !void {
    st.push(@src()); defer st.pop();

    if (buffer.len % 512 != 0) return error.invalidBufferSize;

    const port = device.port;
    const abar = device.abar;
    var buf = buffer;

    port.is = @bitCast(@as(i32, -1));
    const i_slot = find_cmdslot(port, ((abar.cap >> 8) & 0x1F) + 1);

    if (i_slot == -1) return error.noCmdSlot;
    const slot: usize = @bitCast(i_slot);

    const cmdheader_list = mem.ptr_from_paddr([*]HBACMDHeader, @as(u64, @intCast(port.clbu)) << 32 | @as(u64, @intCast(port.clb)));
    const cmdheader = &cmdheader_list[slot];
    cmdheader.cfl = @sizeOf(FIS_Reg_H2D) / @sizeOf(u32);

    cmdheader.w = 0;
    cmdheader.prdtl = @truncate(std.math.divCeil(usize, buf.len, 0x4000) catch unreachable);

    const cmdtbl = mem.ptr_from_paddr(*HBACMDTable, @as(u64, @intCast(cmdheader.ctbau)) << 32 | @as(u64, @intCast(cmdheader.ctba)));
    const total_prdt_size = @sizeOf(HBACMDTable) + (cmdheader.prdtl - 1) * @sizeOf(HBAPRDTEntry);
    @memset(@as([*]u8, @ptrCast(cmdtbl))[0..total_prdt_size], 0);

    for (0 .. cmdheader.prdtl - 1) |i| {
        const phys_buf = mem.paddr_from_vaddr(@intFromPtr(buf.ptr));
        cmdtbl.prdt_entry(i).dba =  @intCast(phys_buf & 0xFFFFFFFF);
        cmdtbl.prdt_entry(i).dbau = @intCast(phys_buf >> 32);
        cmdtbl.prdt_entry(i).i = 1;
        buf = buf[4 * 1024 ..];
    }

    const phys_buf = mem.paddr_from_vaddr(@intFromPtr(buf.ptr));
    cmdtbl.prdt_entry(cmdheader.prdtl - 1).dba =  @truncate(phys_buf & 0xFFFFFFFF);
    cmdtbl.prdt_entry(cmdheader.prdtl - 1).dbau = @truncate(phys_buf >> 32);
    cmdtbl.prdt_entry(cmdheader.prdtl - 1).dbc = @truncate(buf.len - 1);
    cmdtbl.prdt_entry(cmdheader.prdtl - 1).i = 1;

    const cmdfis: *FIS_Reg_H2D = @ptrCast(&cmdtbl.cfis);

    cmdfis.fis_type = 0x27;
    cmdfis.c = 1;
    cmdfis.command = 0x25;

    cmdfis.lba0 = @truncate((sector >> 0) & 0xFF);
    cmdfis.lba1 = @truncate((sector >> 8) & 0xFF);
    cmdfis.lba2 = @truncate((sector >> 16) & 0xFF);
    cmdfis.lba3 = @truncate((sector >> 24) & 0xFF);
    cmdfis.lba4 = @truncate((sector >> 32) & 0xFF);
    cmdfis.lba5 = @truncate((sector >> 40) & 0xFF);

    cmdfis.device = 1 << 6;
    const sector_count = @divExact(buf.len, 512);
    cmdfis.countl = @truncate(sector_count & 0xFF);
    cmdfis.counth = @truncate((sector_count >> 8) * 0xFF);

    var spin: usize = 0;
    while ((port.tfd & (0x88) != 0) and spin < 1000000) : (spin += 1) {}

    if (spin == 1000000) {
        write.err("Port is hung", .{});
        return error.portIsHung;
    }

    port.ci = std.math.shl(u32, 1, slot);

    while (true) {
        if ((port.ci & std.math.shl(u32, 1, slot)) == 0) break;
        if ((port.is & (1 << 30)) != 0) {
            write.err("Read disk error", .{});
            return error.readError;
        }
    }
}

fn iterate_ports(abar: *HBAMem) void {
    st.push(@src()); defer st.pop();

    write.dbg("Iterating though ports...", .{});

    // Search disk in implemented ports
    var pi: u32 = abar.pi;
    var i: usize = 0;
    while (i < 32) : ({i += 1; pi >>= 1;}) {
        if (pi & 1 != 0) {
            
            const port = abar.ports(i);
            const dt = check_type(port);
            if (dt == .sata) {
                write.log("SATA drive found in port {}", .{i});
                init_sata(abar, port);
            }
            else if (dt == .satapi) write.log("SATAPI drive found in port {}", .{i})
            else if (dt == .semb) write.log("SEMB drive found in port {}", .{i})
            else if (dt == .pm) write.log("PM drive found in port {}", .{i});
        }
    }
}
fn check_type(port: *HBAPort) AHCIDevice {
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

fn init_sata(abar: *HBAMem, port: *HBAPort) void {
    stop_cmd(port);
    start_cmd(port);

    const entry = disk.allocate_disk();
    entry.data.* = .{
        .ahci = .{
            .kind = .sata,
            .abar = abar,
            .port = port
        }
    };

    disk.mount_disk(entry.index);
}

fn start_cmd(port: *HBAPort) void {
    while (port.cmd & 0x8000 != 0) {}
    port.cmd |= 0x0010;
    port.cmd |= 0x0001;
}
fn stop_cmd(port: *HBAPort) void {
    port.cmd &= ~@as(u32, 0x0001);
    port.cmd &= ~@as(u32, 0x0010);

    while (true) {
        if (port.cmd & 0x4000 != 0) continue;
        if (port.cmd & 0x8000 != 0) continue;
        break;
    }
}

fn find_cmdslot(port: *HBAPort, cmdslots: usize) isize {
    var slots = (port.sact | port.ci);
    for (0..cmdslots) |i| {
        if ((slots & 1) == 0) return @bitCast(i);
        slots >>= 1;
    }

    write.err("Cannot find a free command list entry", .{});
    return -1;
}

pub const AHCIDevice = enum {
    _null,
    sata,
    semb,
    pm,
    satapi
};

pub const FISType = enum(u8) {
    FIS_TYPE_REG_H2D	= 0x27,	// Register FIS - host to device
	FIS_TYPE_REG_D2H	= 0x34,	// Register FIS - device to host
	FIS_TYPE_DMA_ACT	= 0x39,	// DMA activate FIS - device to host
	FIS_TYPE_DMA_SETUP	= 0x41,	// DMA setup FIS - bidirectional
	FIS_TYPE_DATA		= 0x46,	// Data FIS - bidirectional
	FIS_TYPE_BIST		= 0x58,	// BIST activate FIS - bidirectional
	FIS_TYPE_PIO_SETUP	= 0x5F,	// PIO setup FIS - device to host
	FIS_TYPE_DEV_BITS	= 0xA1,	// Set device bits FIS - device to host
};
pub const AHCIDeviceEntry = struct {
    kind: AHCIDevice,
    abar: *HBAMem,
    port: *HBAPort,
};

// FIS register - Host to Device
pub const FIS_Reg_H2D = packed struct {
    fis_type: u8,
    pmport: u4,
    _reserved_0: u3,
    c: u1,

    command: u8,
    featurel: u8,

    lba0: u8,
    lba1: u8,
    lba2: u8,
    device: u8,

    lba3: u8,
    lba4: u8,
    lba5: u8,
    featureh: u8,

    countl: u8,
    counth: u8,
    icc: u8,
    control: u8,

    _reserved_1: u64
};
// FIS register - Device to Host
pub const FIS_Reg_D2H = packed struct {
    fis_type: u8,
    pmport: u4,
    _reserved_0: u2,
    i: u1,
    _reserved_1: u1,

    status: u8,
    @"error": u8,

    lba0: u8,
    lba1: u8,
    lba2: u8,
    device: u8,

    lba3: u8,
    lba4: u8,
    lba5: u8,
    _reserved_2: u8,

    countl: u8,
    counth: u8,
    _reserved_3: u16,
    _reserved_4: u64
};

pub const FISData = packed struct {
    fis_type: u8,
    pmport: u4,
    _reserved_0: u4,
    _reserved_1: u16,
    __data__: u32,

    pub fn data(s: *@This()) [*]u32 {
        return @ptrCast(&s.__data__);
    }
};
pub const FISPIOSetup = packed struct {
    fis_type: u8,

    pmport: u4,
    _reserved_0: u1,
    d: u1,

    i: u1,
    _reserved_1: u1,

    status: u8,
    @"error": u8,

    lba0: u8,
    lba1: u8,
    lba2: u8,
    device: u8,

    lba3: u8,
    lba4: u8,
    lba5: u8,
    _reserved_2: u8,

    countl: u8,
    counth: u8,
    _reserved_3: u8,
    e_status: u8,

    tc: u16,
    _reserved_4: u16
};
pub const FISDMASetup = packed struct {
    fis_type: u8,

    pmport: u4,
    _reserved_0: u1,
    d: u1,

    i: u1,
    a: u1,

    _reserved_1: u16,
    DMAbufferID: u64,

    _reserved_2: u32,

    DMAbufferOffset: u32,

    TransferCount: u32,

    _reserved_3: u32
};

pub const HBAMem = extern struct {
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

    // 0x2C - 0x9F, Reserved
    _reserved_0: [116]u8,

    vendor: [96]u8,

    __ports__: HBAPort,

    pub fn ports(s: *@This(), i: usize) *HBAPort {
        return &@as([*]HBAPort, @ptrCast(&s.__ports__))[i];
    }
};
pub const HBAPort = extern struct {
    clb: u32,
    clbu: u32,
    fb: u32,
    fbu: u32,
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
pub const HBA_FIS = extern struct {
    dsfis: FISDMASetup,
    _padding_0: u32,

    psfis: FISPIOSetup,
    _padding_1: [4]u8,

    rfis: FIS_Reg_D2H,
    _padding_2: [4]u8,

    // wtf is FIS_DEV_BITS???
    sdbfis: u8,

    ufis: [64]u8,

    _reserved_0: [96]u8
};

pub const HBACMDHeader = packed struct {
    cfl: u5,
    a: u1,
    w: u1,
    p: u1,

    r: u1,
    b: u1,
    c: u1,
    _reserved_0: u1,
    pmp: u4,

    prdtl: u16,

    prdbc: u32,

    ctba: u32,
    ctbau: u32,

    _reserved_1: u32,
    _reserved_2: u32,
    _reserved_3: u32,
    _reserved_4: u32,
};
pub const HBACMDTable = extern struct {
    cfis: [64]u8,
    acmd: [16]u8,
    _reserved_0: [48]u8,
    __prdt_entry__: HBAPRDTEntry,

    pub fn prdt_entry(s: *@This(), i: usize) *HBAPRDTEntry {
        return &@as([*]HBAPRDTEntry, @ptrCast(&s.__prdt_entry__))[i];
    }
};
pub const HBAPRDTEntry = packed struct {
    dba: u32,
    dbau: u32,
    _reserved_0: u32,

    dbc: u22,
    _reserved_1: u9,
    i: u1
};
