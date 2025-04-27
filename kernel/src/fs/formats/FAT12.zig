const os = @import("root").os;
const std = @import("std");

const fs = os.fs;
const disk = os.drivers.disk;
const format = os.fs.format;

const print = os.console_write("partitions");
const st = os.stack_tracer;

pub fn analyze_partition(dev: disk.DiskEntry, node: *fs.FsNode, start: usize, end: usize) void {
    st.push(@src()); defer st.pop();

    _ = node;
    _ = end;

    print.dbg("start sector: {}", .{ start });

    var buf: [512]u8 = undefined;
    disk.read(dev, start, &buf) catch unreachable;

    const bpb = std.mem.bytesToValue(BootSector, &buf);

    const root_dir_sectors = std.math.divCeil(usize,
        bpb.root_entry_count * 32,
        bpb.bytes_per_sector) catch unreachable;

    const first_data_sector = bpb.reserved_sector_count
        + (bpb.table_count * bpb.table_size_16)
        + root_dir_sectors
        + start;
    
    print.log("{} FAT table sectors found in {}+. Iterating...", .{root_dir_sectors, first_data_sector});

    for (0 .. root_dir_sectors) |i| {
        print.log("--- Sector {} ---", .{i});
        disk.read(dev, first_data_sector + i, &buf) catch unreachable;

        const entries: []DirEntry = @alignCast(std.mem.bytesAsSlice(DirEntry, &buf));

        for (entries) |entry| {
            //if (entry.name[0] == 0x00) break;
            print.log("({X:0>2}) {s: <10}.{s} - {} bytes", .{entry.name[0], entry.get_name(), entry.get_extension(), entry.file_size});
        }
    }
}

const BootSector = packed struct {
    jump: u24,
    oem_name: u64,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sector_count: u16,
    table_count: u8,
    root_entry_count: u16,
    total_sectors_16: u16,
    media_descriptor: u8,
    table_size_16: u16,
    sectors_per_track: u16,
    head_side_count: u16,
    hidden_sector_count: u32,
    total_sectors_32: u32,

    pub fn total_sectors(s: *@This()) usize {
        return if (s.total_sectors_16 == 0) s.total_sectors_32
        else s.total_sectors_16;
    }
};

const DirEntry = extern struct {
    name: [8]u8,
    extension: [3]u8,
    file_attributes: u8,
    user_attributes: u8,
    creation_time_tenths: u8,
    creation_time: u16,
    creation_date: u16,
    last_access_date: u16,
    first_cluster_high: u16,
    last_modified_time: u16,
    last_modified_date: u16,
    first_cluster_low: u16,
    file_size: u32,

    pub fn is_free(self: *const DirEntry) bool {
        return self.name[0] == 0x00 or self.name[0] == 0xE5;
    }

    pub fn is_directory(self: *const DirEntry) bool {
        return (self.attr & 0x10) != 0;
    }

    pub fn get_name(self: *const DirEntry) []const u8 {
        return std.mem.trim(u8, &self.name, &[_]u8{' '});
    }

    pub fn get_extension(self: *const DirEntry) []const u8 {
        return std.mem.trim(u8, &self.extension, &[_]u8{' '});
    }
};
