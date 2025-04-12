const os = @import("root").os;
const std = @import("std");

const disk = os.drivers.disk;
const format = os.fs.format;

const print = os.console_write("partitions");
const st = os.stack_tracer;

pub fn scan_partitions(driver: disk.DiskEntry) void {

    var sector: [512]u8 = undefined;
    disk.read(driver, 0, &sector);

    if (sector[0x1FE] != 0x55 or sector[0x1FF] != 0xAA) return;

    for (0 .. 4) |i| {
        const base = 0x1BE + i * 16;
        const edata = sector[base..];

        const entry = PartTableEntry {
            .status = edata[0],
            .chs_addr_l = std.mem.readInt(u24, edata[1..4], .little),
            .part_type = edata[4],
            .chs_addr_h = std.mem.readInt(u24, edata[5..8], .little),
            .lba_sector = std.mem.readInt(u32, edata[8..12], .little),
            .sector_size = std.mem.readInt(u32, edata[12..16], .little)
        };

        if (entry.part_type == 0xEE) {
            scan_gpt_table(driver);
            return;
        }

    }

}

fn scan_gpt_table(driver: disk.DiskEntry) void {

    var sector: [512]u8 = undefined;
    disk.read(driver, 1, &sector);

    // TODO only work for little-endian CPUs
    const header = std.mem.bytesToValue(GPTHeader, sector[0 .. @sizeOf(GPTHeader)]);

    const total_size = header.num_part_entries * header.size_of_part_entry;
    const sector_count = std.math.divCeil(usize, total_size, 512) catch unreachable;

    const buffer = os.memory.allocator.alloc(u8, sector_count * 512) catch unreachable;
    defer os.memory.allocator.free(buffer);
    disk.read(driver, header.part_entry_lba, buffer);

    const entries = std.mem.bytesAsSlice(GPTEntry, buffer);

    const drive_node = os.fs.get_drive_node(driver.index);

    var buf: [36]u8 = undefined;
    for (entries) |i| {
        if (i.type_guid.is_zero()) continue;

        _ = std.unicode.utf16LeToUtf8(&buf, &i.name) catch unreachable;
        print.dbg(\\ name: {s}
        \\ type guid: {}
        \\ start: 0x{X}
        \\ size: {}
        , .{ std.mem.sliceTo(&buf, 0), i.type_guid, i.first_lba * 512, i.last_lba - i.first_lba });

        var guid_buf: [36]u8 = undefined;
        _ = std.fmt.bufPrint(&guid_buf, "{}", .{i.type_guid}) catch unreachable;

        var partType: PartitionType = .unitialized;

        // Basic Data Partition
        if (std.mem.eql(u8, &guid_buf, "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7")) {
            partType = format.BasicData.detect_partition_type(driver, i);
        }

        // EFI Partition
        else if (std.mem.eql(u8, &guid_buf, "C12A7328-F81F-11D2-BA4B-00A0C93EC93B")) {
            partType = format.EFISystem.detect_partition_type(driver, i);
        }

        if (partType == .unitialized) {
            // Partition type not recognized
            print.warn("Partition not recognized!", .{});
            continue;
        }

        _ = std.unicode.utf16LeToUtf8(&buf, &i.name) catch unreachable;
        _ = drive_node.branch(std.mem.sliceTo(&buf, 0), .{ .partition = .{
            .part_type = partType,
            .sectors_start = @truncate(i.first_lba),
            .sectors_end = @truncate(i.last_lba)
        }});

        switch (partType) {
            else => |t| print.err("Partition type {s} not implemented!", .{@tagName(t)})
        }

    }
}

pub const GUID = extern struct {
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,

    pub fn is_zero(s: @This()) bool {
        return s.data1 == 0 and s.data2 == 0 and s.data3 == 0 and std.mem.eql(u8, &s.data4, &[_]u8{0} ** 8);
    }
    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype,) !void {
        try writer.print("{X:0>8}-{X:0>4}-{X:0>4}-{X:0>2}{X:0>2}-{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}",
            .{
                self.data1,
                self.data2,
                self.data3,
                self.data4[0], self.data4[1],
                self.data4[2], self.data4[3], self.data4[4],
                self.data4[5], self.data4[6], self.data4[7],
            },
        );
    }
};

pub const PartTableEntry = packed struct {
    status: u8,
    chs_addr_l: u24,
    part_type: u8,
    chs_addr_h: u24,
    lba_sector: u32,
    sector_size: u32
};

// GPT
pub const GPTHeader = extern struct {
    signature: [8]u8, // "EFI PART"
    revision: u32,
    header_size: u32,
    crc32: u32,
    reserved: u32,
    current_lba: u64,
    backup_lba: u64,
    first_usable_lba: u64,
    last_usable_lba: u64,
    disk_guid: [16]u8,
    part_entry_lba: u64,
    num_part_entries: u32,
    size_of_part_entry: u32,
    part_entry_array_crc32: u32,
};
pub const GPTEntry = extern struct {
    type_guid: GUID,
    unique_guid: GUID,
    first_lba: u64,
    last_lba: u64,
    flags: u64,
    name: [36]u16, // UTF-16LE
};

pub const PartitionType = enum {
    unitialized,

    iso9660,
    FAT12, FAT16, FAT32,
    ext2, ext4,
    HFS_plus,
};

