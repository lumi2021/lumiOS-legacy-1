const os = @import("root").os;
const std = @import("std");

const fs = os.fs;
const disk = os.drivers.disk;
const format = os.fs.format;

const print = os.console_write("partitions");
const st = os.stack_tracer;

pub fn analyze_partition(dev: disk.DiskEntry, part_node: *fs.FsNode) void {
    st.push(@src()); defer st.pop();

    var data = part_node.data.partition;
    const start = data.sectors_start;

    print.dbg("start sector: {}", .{ start });

    var buf: [512]u8 = undefined;
    disk.read(dev, start, &buf) catch unreachable;

    const bpb = std.mem.bytesToValue(BootSector, &buf);
    
    const fat_start = start + bpb.reserved_sector_count;

    const rds_start = fat_start + (bpb.table_size_16 * bpb.table_count);
    
    const rds_len = std.math.divCeil(usize,
        bpb.root_entry_count * @sizeOf(DirEntry),
        bpb.bytes_per_sector) catch unreachable;

    const data_start = rds_start + rds_len - 2;

    data.part_data = .{ .FAT12 = .{
        .fat_table_ptr = fat_start,
        .fat_table_len = bpb.table_size_16,

        .root_dir_ptr = rds_start,
        .root_dir_len = rds_len,

        .data_start_ptr = data_start
    }};

    print.log("Root directory table ({} sectors) in {} .. {}. Iterating...",
        .{rds_len, rds_start, rds_start + rds_len});

    for (0 .. rds_len) |i| {
        const sector =  rds_start + i;

        print.log("--- Sector {} / {} ---", .{i, sector});
        disk.read(dev, sector, &buf) catch unreachable;

        const entries: []DirEntry = @alignCast(std.mem.bytesAsSlice(DirEntry, &buf));

        for (entries) |entry| {
            if (entry.name[0] == 0x00) break;
            if (@as(u8, @bitCast(entry.file_attributes)) == 0x0f) print.log("(fake entry)", .{})

            else {
                
                var node: *fs.FsNode = undefined;
                if (entry.is_directory()) {
                    
                    print.log("({X:0>2}) {s: <14} - directory", .{entry.name[0], entry.get_name()});
                    node = part_node.branch(entry.get_name(), .{ .directory = undefined });
                } else {
                    print.log("({X:0>2}) {s: <10}.{s <3} - {} bytes",
                        .{entry.name[0], entry.get_name(), entry.get_extension(), entry.file_size});
                    
                    var name_buf: [12]u8 = undefined;
                    const str = std.fmt.bufPrint(&name_buf, "{s}.{s}",
                        .{entry.get_name(), entry.get_extension()}) catch unreachable;

                    node = part_node.branch(str, .{ .file = undefined });
                }

                if (entry.is_directory()) {
                    const start_cluster = @as(u32, @intCast(entry.first_cluster_high)) << 16 | entry.first_cluster_low;
                    const pointing_to = data_start + start_cluster;

                    print.log("(Directory pointing to {})", .{pointing_to});
                    if (entry.name[0] == '.') continue;

                    parse_subdirectory(&data.part_data, node, start_cluster);
                }

            }
        }
    }
}

fn parse_subdirectory(partdata: *PartitionData, parent_node: *fs.FsNode, offset: usize) void {
    st.push(@src()); defer st.pop();

    var buf: [512]u8 = undefined;

    const data_start = partdata.FAT12.data_start_ptr;
    const dev = partdata.get_disk_device();

    var i: usize = offset;
    while (true) {
        const sector =  data_start + i;

        print.log("--- Sector {} / {} ---", .{i, sector});
        disk.read(dev, sector, &buf) catch unreachable;

        const entries: []DirEntry = @alignCast(std.mem.bytesAsSlice(DirEntry, &buf));

        for (entries) |entry| {
            if (entry.name[0] == 0x00) break;
            if (@as(u8, @bitCast(entry.file_attributes)) == 0x0f) print.log("(fake entry)", .{})

            else {
                
                var node: *fs.FsNode = undefined;
                if (entry.is_directory()) {
                    
                    print.log("({X:0>2}) {s: <14} - directory", .{entry.name[0], entry.get_name()});
                    node = parent_node.branch(entry.get_name(), .{ .directory = undefined });
                } else {
                    print.log("({X:0>2}) {s: <10}.{s <3} - {} bytes",
                        .{entry.name[0], entry.get_name(), entry.get_extension(), entry.file_size});
                    
                    var name_buf: [12]u8 = undefined;
                    const str = std.fmt.bufPrint(&name_buf, "{s}.{s}",
                        .{entry.get_name(), entry.get_extension()}) catch unreachable;

                    node = parent_node.branch(str, .{ .file = undefined });
                }

                if (entry.is_directory()) {
                    const start_cluster = @as(u32, @intCast(entry.first_cluster_high)) << 16 | entry.first_cluster_low;
                    const pointing_to = data_start + start_cluster;

                    print.log("(Directory pointing to {})", .{pointing_to});
                    if (entry.name[0] == '.') continue;

                    parse_subdirectory(partdata, node, start_cluster);
                }

            }
        }

        i = get_next_sector(partdata, i) orelse break;
    }
    
}

fn get_next_sector(partdata: *PartitionData, current: usize) ?usize {
    _ = partdata;
    _ = current;

    return null;
}

const PartitionData = fs.partitions.PartitionData;

const BootSector = packed struct {
    jump: u24, // 3
    oem_name: u64, // 11
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
    file_attributes: DirEntryFileAttributes,
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

    pub inline fn is_directory(self: *const DirEntry) bool {
        return self.file_attributes.directory;
    }

    pub fn get_name(self: *const DirEntry) []const u8 {
        return std.mem.trim(u8, &self.name, &[_]u8{' '});
    }

    pub fn get_extension(self: *const DirEntry) []const u8 {
        return std.mem.trim(u8, &self.extension, &[_]u8{' '});
    }
};
const DirEntryFileAttributes = packed struct(u8) {
    read_only: bool,
    hidden: bool,
    system: bool,
    volume_label: bool,
    directory: bool,
    dirty: bool,
    _reserved_0: u2,
};
