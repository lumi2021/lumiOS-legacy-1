const std = @import("std");
const os = @import("root").os;

const ports = os.port_io;
const primary_io = 0x1F0;
const primary_ctl = 0x3F6;

const pci = os.drivers.pci;
pub const ahci = @import("ahci.zig");

const write = os.console_write("Disk");
const st = os.stack_tracer;

const DiskList = std.ArrayList(*DiskEntry);
pub var disk_list: DiskList = undefined;

pub fn init() void {
    disk_list = DiskList.init(os.memory.allocator);
}

pub const register_AHCI_drive = ahci.init_device;

pub fn read(disk: *DiskEntry, addr: u64, buffer: []u8) void {
    switch (disk.data) {
        .sata, .semb, .pm, .satapi => |*d| ahci.read(d, addr, buffer) catch undefined
    }
}

pub const DiskEntry = struct {
    index: u8,
    data: DiskData
};
const DiskData = union(DiskType) {
    sata: ahci.AHCIDeviceEntry,
    semb: ahci.AHCIDeviceEntry,
    pm: ahci.AHCIDeviceEntry,
    satapi: ahci.AHCIDeviceEntry
};

pub const DiskType = enum {
    sata,
    semb,
    pm,
    satapi
};
