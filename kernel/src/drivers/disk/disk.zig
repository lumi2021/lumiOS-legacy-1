const std = @import("std");
const os = @import("root").os;

const ports = os.port_io;
const primary_io = 0x1F0;
const primary_ctl = 0x3F6;

const pci = os.drivers.pci;

const write = os.console_write("Disk");
const st = os.stack_tracer;

const DiskList = std.ArrayList(Disk);
var disk_list: DiskList = undefined;

pub fn init() void {
    disk_list = DiskList.init(os.memory.allocator);
}

// Registers
pub fn register_SATA_drive(addr: pci.Addr) void {

    _ = addr;

}


const Disk = struct {
    type: DiskType,
    name: [16]u8
};

const DiskType = enum {
    SATA,
    IDE,
    ATAPI
};