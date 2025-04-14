const os = @import("root").os;
const std = @import("std");

const fs = os.fs;
const disk = os.drivers.disk;
const format = os.fs.format;

const print = os.console_write("partitions");
const st = os.stack_tracer;

pub fn analyze_partition(dev: disk.DiskEntry, node: fs.FsNode, start: usize, end: usize) void {
    _ = dev;
    _ = node;
    _ = start;
    _ = end;
}

const BootSector = extern struct {
    jump: [3]u8,
    oem_name: [8]u8,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    fat_count: u8,
    root_dir_entries: u16,
    total_sectors_short: u16,
    media_descriptor: u8,
    sectors_per_fat: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    total_sectors_long: u32,
    drive_number: u8,
    __reserved__0: u8,
    boot_signature: u8,
    volume_id: u32,
    volume_label: [11]u8,
    fs_type: [8]u8,
};

const DirEntry = packed struct {
    name: [8]u8,
    extension: [3]u8,
    attributes: u8,
    reserved: [10]u8,
    time: u16,
    date: u16,
    start_cluster: u16,
    size: u32,
};

