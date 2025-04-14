const os = @import("root").os;
const std = @import("std");

const disk = os.drivers.disk;
const partitions = os.fs.partitions;
const format = os.fs.format;
const PartitionType = partitions.PartitionType;

const print = os.console_write("partitions");
const st = os.stack_tracer;

const GPTEntry = partitions.GPTEntry;

pub fn detect_partition_type(driver: disk.DiskEntry, entry: GPTEntry) PartitionType {
    st.push(@src()); defer st.pop();

    var sec_buf: [512]u8 = undefined;
    disk.read(driver, entry.first_lba, &sec_buf);

    const bpb = std.mem.bytesToValue(BPB, &sec_buf);

    if (bpb.fat_size_16 == 0) return .FAT32;

    const bytes_per_sector:usize = @intCast(bpb.bytes_per_sector);
    const total_sectors: usize = if (bpb.num_sectors_16 != 0) @intCast(bpb.num_sectors_16) else @intCast(bpb.num_sectors_32);
    const fat_sectors: usize = @intCast(bpb.fat_size_16);
    const num_fats: usize = @intCast(bpb.num_fats);
    const reserved_sectors: usize = @intCast(bpb.reserved_sectors);
    const root_entry_count: usize = @intCast(bpb.root_entry_count);

    const root_dir_sectors: usize = ((root_entry_count * 32) + (bytes_per_sector - 1)) / bytes_per_sector;
    const data_sectors: usize = total_sectors - (reserved_sectors + (num_fats * fat_sectors) + root_dir_sectors);
    const clusters = data_sectors / @as(usize, @intCast(bpb.sectors_per_cluster));
    print.dbg("num of clusters: {}", .{clusters});

    if (clusters < 4085) return .FAT12;
    if (clusters < 65525) return .FAT16;
    
    return .FAT32;
}

const BPB = packed struct {
    jmp_instruction: u24,
    OEM_identifier: u64,

    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    num_fats: u8,
    root_entry_count: u16,
    num_sectors_16: u16,
    media_type: u8,
    fat_size_16: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    num_sectors_32: u32
};
