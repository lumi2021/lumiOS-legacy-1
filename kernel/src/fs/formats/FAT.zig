const os = @import("root").os;
const std = @import("std");

const fs = os.fs;
const disk = os.drivers.disk;
const part = os.fs.partitions;
const format = os.fs.format;

const print = os.console_write("partitions");
const st = os.stack_tracer;

pub fn analyze_partition(part_node: *fs.FsNode) void {
    st.push(@src()); defer st.pop();

    const device_node = part_node.parent;
    const drive = device_node.?.data.disk;
    const entry = part_node.data.partition;

    var buf: [512]u8 = undefined;
    disk.read(drive, entry.sectors_start, &buf) catch unreachable;

    const bpb = std.mem.bytesToValue(BootSector, &buf);

    const start = entry.sectors_start;

    const bytes_per_sector:usize = @intCast(bpb.bytes_per_sector);
    const total_sectors: usize = if (bpb.total_sectors_16 != 0) @intCast(bpb.total_sectors_16) else @intCast(bpb.total_sectors_32);
    const fat_sectors: usize = @intCast(bpb.table_size_16);
    const num_fats: usize = @intCast(bpb.table_count);
    const reserved_sectors: usize = @intCast(bpb.reserved_sector_count);
    const root_entry_count: usize = @intCast(bpb.root_entry_count);

    const fat_start = start + reserved_sectors;
    const fat_length = (fat_sectors * num_fats);
    const root_dir_table_start = fat_start + fat_length;
    const root_dir_table_len = std.math.divCeil(usize,
        root_entry_count * @sizeOf(DirEntry),
        bytes_per_sector) catch unreachable;
    
    const data_start = root_dir_table_start + root_dir_table_len;
    const data_len: usize = total_sectors - data_start;

    const clusters = data_len / @as(usize, @intCast(bpb.sectors_per_cluster));

    const ftype: FATType = b: {
        if (clusters < 4085) break :b .FAT12;
        if (clusters < 65525) break :b .FAT16;
        break :b .FAT32;
    };

    part_node.data.partition.file_system = .{ .vFAT = .{
        .fat_type = ftype,

        .fat_table_ptr = fat_start,
        .fat_table_len = fat_length,

        .root_dir_ptr = root_dir_table_start,
        .root_dir_len = root_dir_table_len,

        .data_start_ptr = data_start,
    }};

    print.dbg("clusters: {}; fat: {s}", .{ clusters, @tagName(ftype) });

    var long_name_buf: [256]u16 = undefined;
    var utf8_long_name_buf: [512]u8 = undefined;
    var long_name_idx: usize = 0;

    for (0 .. root_dir_table_len) |i| {
        const sector =  root_dir_table_start + i;

        disk.read(drive, sector, &buf) catch unreachable;

        const entries: []DirEntry = @alignCast(std.mem.bytesAsSlice(DirEntry, &buf));

        for (entries, 0..) |e, idx| {
            if (e.name[0] == 0x00) break;

            if (@as(u8, @bitCast(e.file_attributes)) == 0x0f) {
                long_name_idx += 1;

                const str_idx = 512 - long_name_idx * 26;
                const entry_idx = idx * 32;
                const buf_u8 = @as([*]u8, @ptrCast(&long_name_buf));

                @memcpy(buf_u8[str_idx..],      buf[entry_idx + 0x01 .. entry_idx + 0x0B]); // 5 chars, 10 bytes
                @memcpy(buf_u8[str_idx + 10..], buf[entry_idx + 0x0E .. entry_idx + 0x1A]); // 6 chars, 12 bytes
                @memcpy(buf_u8[str_idx + 22..], buf[entry_idx + 0x1C .. entry_idx + 0x20]); // 2 chars, 4  bytes
            }

            else { // Is valid entry

                var long_name: ?[]u8 = null;

                if (long_name_idx > 0) {
                    const str_idx = 256 - long_name_idx * 13;
                    _  = std.unicode.utf16LeToUtf8(&utf8_long_name_buf, long_name_buf[str_idx ..]) catch unreachable;
                    long_name = std.mem.sliceTo(&utf8_long_name_buf, 0);
                }
                @memset(&long_name_buf, 0);
                long_name_idx = 0;

                var name_buf: [12]u8 = undefined;

                var node: *fs.FsNode = undefined;

                if (!e.is_directory()) {

                   const str_name = long_name orelse std.fmt.bufPrint(&name_buf, "{s}.{s}",
                        .{e.get_name(), e.get_extension()}) catch unreachable;
                    node = part_node.branch(str_name, .{ .file = undefined });

                }
                
                else {

                    const str_name = long_name orelse e.get_name();
                    node = part_node.branch(str_name, .{ .directory = undefined });

                    const start_cluster = @as(u32, @intCast(e.first_cluster_high)) << 16 | e.first_cluster_low;
                    if (e.name[0] == '.') continue;

                    parse_subdirectory(part_node, node, start_cluster - 2);

                }

            }
        }
    }
}

fn parse_subdirectory(part_node: *fs.FsNode, parent_node: *fs.FsNode, offset: usize) void {
    st.push(@src()); defer st.pop();

    var buf: [512]u8 = undefined;

    const vfat = part_node.data.partition.file_system.vFAT;
    const data_start = vfat.data_start_ptr;
    const dev = part_node.parent.?.data.disk;

    var sector: usize = data_start + offset;
    sec: while (true) {

        disk.read(dev, sector, &buf) catch unreachable;

        const entries: []DirEntry = @alignCast(std.mem.bytesAsSlice(DirEntry, &buf));

        var long_name_buf: [256]u16 = undefined;
        var utf8_long_name_buf: [512]u8 = undefined;
        var long_name_idx: usize = 0;

        for (entries, 0..) |entry, i| {
            if (entry.name[0] == 0x00) break :sec;
            if (@as(u8, @bitCast(entry.file_attributes)) == 0x0f) {
                long_name_idx += 1;

                const str_idx = 512 - long_name_idx * 26;
                const entry_idx = i * 32;
                const buf_u8 = @as([*]u8, @ptrCast(&long_name_buf));

                @memcpy(buf_u8[str_idx..],      buf[entry_idx + 0x01 .. entry_idx + 0x0B]); // 5 chars, 10 bytes
                @memcpy(buf_u8[str_idx + 10..], buf[entry_idx + 0x0E .. entry_idx + 0x1A]); // 6 chars, 12 bytes
                @memcpy(buf_u8[str_idx + 22..], buf[entry_idx + 0x1C .. entry_idx + 0x20]); // 2 chars, 4  bytes
            }
            else { // Is valid entry
                
                var node: *fs.FsNode = undefined;
                var long_name: ?[]u8 = null;

                if (long_name_idx > 0) {
                    const str_idx = 256 - long_name_idx * 13;
                    _ = std.unicode.utf16LeToUtf8(
                        &utf8_long_name_buf,
                        long_name_buf[str_idx ..]
                    ) catch unreachable;
                    long_name = std.mem.sliceTo(&utf8_long_name_buf, 0);
                }
                long_name_idx = 0;

                var name_buf: [12]u8 = undefined;

                if (!entry.is_directory()) {
                    const str_name = long_name orelse std.fmt.bufPrint(&name_buf, "{s}.{s}",
                        .{entry.get_name(), entry.get_extension()}) catch unreachable;
                    
                    const start_cluster = entry.get_cluster().?;
                    const size = std.mem.readInt(u32, buf[i * 32 + 28..][0..4], .little);

                    node = parent_node.branch(str_name, .{ .file = .{
                        .sector_start = data_start + start_cluster,
                        .size = size
                    } });
                } else {
                    const str_name = long_name orelse entry.get_name();
                    node = parent_node.branch(str_name, .{ .directory = undefined });

                    const start_cluster = @as(u32, @intCast(entry.first_cluster_high)) << 16 | entry.first_cluster_low;
                    
                    const pointing_to = data_start + start_cluster - 2;

                    print.log("(Directory pointing to {})", .{pointing_to});
                    if (entry.name[0] == '.') continue;

                    parse_subdirectory(part_node, node, start_cluster - 2);
                }
            }
        }

        sector = get_next_sector(part_node, sector) orelse break;

    }
    
}

fn get_next_sector(part_node: *fs.FsNode, current: usize) ?usize {
    st.push(@src()); defer st.pop();

    var buf: [512]u8 = undefined;

    const vfat = part_node.data.partition.file_system.vFAT;
    const fat_t = vfat.fat_type;
    const fat_start = vfat.fat_table_ptr;
    const dev = part_node.parent.?.data.disk;

    if (fat_t == .FAT12) {
        const iseven = current % 2 == 0;
        const fat_index = (current * 3) / 2;
        const sector_off = fat_index / 512;
        const rel_index = fat_index % 512;

        disk.read(dev, fat_start + sector_off, &buf) catch unreachable;

        print.dbg("Seeking cluster {} of sector {} ({} in sector {} of fat table)...",
            .{fat_index, current, rel_index, sector_off});

        const raw_cluster = std.mem.readInt(u16, buf[rel_index..][0..2], .little);
        const cluster = if (iseven) (raw_cluster & 0x0fff) else (raw_cluster >> 4);

        print.dbg("found cluster {} (0x{X:0>3})", .{cluster, cluster});

        return if (cluster >= 0x002 and cluster <= 0xfef) (cluster - 2) else null;
    }
    else if (fat_t == .FAT16) {
        const fat_index = current * 2;
        const sector_off = fat_index / 512;
        const rel_index = fat_index % 512;
        disk.read(dev, fat_start + sector_off, &buf) catch unreachable;

        const cluster = std.mem.readInt(u16, buf[rel_index..][0..2], .little);
        return if (cluster >= 0x0002 and cluster <= 0xffef) (cluster - 2) else null;
    }
    else {
        const fat_index = current * 4;
        const sector_off = fat_index / 512;
        const rel_index = fat_index % 512;
        disk.read(dev, fat_start + sector_off, &buf) catch unreachable;

        const cluster = std.mem.readInt(u32, buf[rel_index..][0..4], .little);
        return if (cluster >= 0x0000_0002 and cluster <= 0xffff_ffef) (cluster - 2) else null;
    }
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

    pub inline fn is_lfn_entry(self: *const DirEntry) bool {
        return @as(u8, @bitCast(self.file_attributes)) == 0x0F;
    }

    pub fn get_name(self: *const DirEntry) []const u8 {
        return std.mem.trim(u8, &self.name, &[_]u8{' '});
    }

    pub fn get_extension(self: *const DirEntry) []const u8 {
        return std.mem.trim(u8, &self.extension, &[_]u8{' '});
    }

    pub fn get_cluster(self: *const DirEntry) ?u32 {
        const val = @as(u32, @intCast(self.first_cluster_high)) << 16 | self.first_cluster_low;
        return if (val < 2) null else val;
    }
};

pub const FileSystem_FAT_Data = struct {
    fat_type: FATType,

    fat_table_ptr: usize,
    fat_table_len: usize,

    root_dir_ptr: usize,
    root_dir_len: usize,

    data_start_ptr: usize
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

const FATType = enum { FAT12, FAT16, FAT32 };
