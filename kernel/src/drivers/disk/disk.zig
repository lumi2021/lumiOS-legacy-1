// This file is only for the device side of the disk.
// For the data side, see fs/drives.zig

const std = @import("std");
const os = @import("root").os;

const ports = os.port_io;
const primary_io = 0x1F0;
const primary_ctl = 0x3F6;

const fs = os.fs;
const pci = os.drivers.pci;
pub const ahci = @import("ahci.zig");

const write = os.console_write("Disk");
const st = os.stack_tracer;

var disk_list: []DiskData = undefined;
pub fn get_disk_data(i: usize) *DiskData { return &disk_list[i]; }

var arena: std.heap.ArenaAllocator = undefined;
var alloc: std.mem.Allocator = undefined;

pub fn init() void {
    arena = std.heap.ArenaAllocator.init(os.memory.allocator);
    alloc = arena.allocator();

    disk_list = alloc.alloc(DiskData, 16) catch unreachable;
    @memset(disk_list, .{ .unitialized = undefined });
}
pub fn allocate_disk() DiskEntry {
    const drive_idx = brk: {
        for (0 .. disk_list.len) |i| {
            if (disk_list[i] == .unitialized) break :brk i;
        }
        // TODO fix support for more disks
        @panic("WTF who have more than 16 disks in a fucking computer????");
    };
    disk_list[drive_idx] = .{ .unitialized = undefined };
    return .{
        .index = drive_idx,
        .data = &disk_list[drive_idx]
    };
}
pub fn mount_disk(index: usize) void {
    if (disk_list[index] == .unitialized) @panic("Unitialized disk");
    fs.append_disk_drive(.{ .index = index, .data = &disk_list[index] });
    fs.reset_drive(index);
}

pub const register_AHCI_drive = ahci.init_device;

pub fn read(disk: DiskEntry, sector: u64, buffer: []u8) void {
    switch (disk.data.*) {
        .unitialized => @panic("Trying to read unitialized disk"),
        .ahci => |d| ahci.read(d, sector, buffer) catch undefined
    }
}

pub const DiskEntry = struct {
    index: usize,
    data: *DiskData
};
const DiskData = union(DiskType) {
    unitialized: void,
    ahci: ahci.AHCIDeviceEntry
};

pub const DiskType = enum {
    unitialized,
    ahci
};
