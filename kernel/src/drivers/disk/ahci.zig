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

pub fn read(device: *AHCIDeviceEntry, sector: u64, buffer: []u8) !void {
    st.push(@src()); defer st.pop();

    write.warn("lets just ignore this for now", .{});
    if (true) return;

    const sector_low: u32 = @intCast(sector & 0xFFFF_FFFF);
    const sector_high: u32 = @intCast((sector >> 32) & 0xFFFF_FFFF);

    const port = device.port;

    port.interrupt_status = -1;
    const spin: u32 = 0;
    const slot = find_cmdslot(device);

    if (slot == -1) {
        write.err("No free command slots!", .{});
        return;
    }

    const command_header_ptr: [*]HBACommandHeder = @ptrFromInt(@as(usize, @intCast(port.command_list_low))
        | (@as(usize, @intCast(port.command_list_high)) << 32));
    write.warn("command_header ptr: {X:0>16} ({X:0>8}:{X:0>8})", .{@intFromPtr(command_header_ptr), port.command_list_low, port.command_list_high});
    const command_header = &command_header_ptr[@intCast(slot)..][0];

    command_header.command_fis_length = @sizeOf(HBACommandFis) / @sizeOf(u32);
    command_header.write = false;
    command_header.prdt_length = @intCast(((buffer.len - 1) >> 4) + 1);

    const command_table: *HBACommandTable = @ptrFromInt(@as(usize, @intCast(command_header.command_table_base_address_low))
        | (@as(usize, @intCast(command_header.command_table_base_address_high)) << 32));
    write.warn("command_table ptr: {X}", .{@intFromPtr(command_table)});
    command_table.* = std.mem.zeroes(HBACommandTable);

    _ = sector_low;
    _ = sector_high;
    _ = spin;

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

                fs.reset_drive(driveid);
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

    const ssts = port.sata_status;
    const ipm = (ssts >> 8) & 0x0F;
    const det = ssts & 0x0F;

    if (det != 3) return ._null;
    if (ipm != 1) return ._null;

    return switch (port.signature) {
        0xEB140101 => .satapi,
        0xC33C0101 => .semb,
        0x96690101 => .pm,
        else => .sata
    };
}

// Find a free command list slot
fn find_cmdslot(device: *AHCIDeviceEntry) i32 {
    st.push(@src()); defer st.pop();

    // If not set in SACT and CI, the slot is free
    var slots: u32 = (device.port.sata_active | device.port.command_issue);
    const cmdslots = (device.registers.cap & 0x1F) + 1;
    for (0..cmdslots) |i| {
        if ((slots & 1) == 0) return @intCast(i);
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
    command_list_low: u32, command_list_high: u32,
    fis_base_low: u32, fis_base_high: u32,
    interrupt_status: i32,
    interrupt_enable: u32,
    command_status: u32,
    _reserved_0: u32,
    task_file_data: u32,
    signature: u32,
    sata_status: u32,
    sata_control: u32,
    sata_error: u32,
    sata_active: u32,
    command_issue: u32,
    sata_notification: u32,
    fbfis_based_switching_controll: u32,
    _reserved_1: [11]u32,
    vendor: [4]u32,
};

const HBACommandHeder = packed struct {
   command_fis_length: u8,
   atapi: bool,
   write: bool,
   prefetchable: bool,

   reset: bool,
   bist: bool,
   clear_busy_on_ok: bool,
   _reserved_0: u1,
   port_multiplier: u4,

   prdt_length: u16,
   prdb_count: u32,
   command_table_base_address_low: u32,
   command_table_base_address_high: u32,

   _reserved_1: u128
};
const HBACommandFis = packed struct {
    fis_type: u8,
    pm_port: u4,
    _reserved_0: u3,
    command_control: u1,

    command: u8,
    feature_low: u8,

    lba0: u8,
    lba1: u8,
    lba2: u8,
    device_register: u8,

    lba3: u8,
    lba4: u8,
    lba5: u8,
    feature_high: u8,

    count_low: u8,
    count_high: u8,
    icc: u8,
    control: u8,

    _reserved_1: u32,
};
const HBACommandTable = extern struct {
    command_fis: [64]u8,
    atapi_command: [16]u8,
    _reserved_0: [48]u8,
    prdt_entry: [32]u8
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

