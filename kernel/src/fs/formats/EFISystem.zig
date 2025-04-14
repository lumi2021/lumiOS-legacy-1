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

    const total_sectors: usize = if (bpb.total_sectors_16 != 0) @intCast(bpb.total_sectors_16) else @intCast(bpb.total_sectors_32);
    const fat_sectors: usize = if (bpb.fat_size_16 != 0) @intCast(bpb.fat_size_16) else @intCast(bpb.fat_size_32);
    
    // FIXME overflow happening here
    const root_dir_sectors = ((bpb.root_entry_count * 32) + (bpb.bytes_per_sector - 1)) / bpb.bytes_per_sector;
    const data_sectors = total_sectors - (bpb.reserved_sector_count + (bpb.num_fats * fat_sectors) + root_dir_sectors);
    const count_of_clusters = data_sectors / bpb.sectors_per_cluster;

    if (count_of_clusters < 4085) return .FAT12;
    if (count_of_clusters < 65525) return .FAT16;
    
    return .FAT32;
    //return .unitialized;
}

const BPB = extern struct {
    jump_boot: [3]u8,
    oem_name: [8]u8,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sector_count: u16,
    num_fats: u8,
    root_entry_count: u16,
    total_sectors_16: u16,
    media: u8,
    fat_size_16: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    total_sectors_32: u32,
    fat_size_32: u32,
    ext_flags: u16,
    fs_version: u16,
    root_cluster: u32,
    fs_info: u16,
    backup_boot_sector: u16,
    __reserved__0: [12]u8,
    drive_number: u8,
    __reserved__1: u8,
    boot_signature: u8,
    volume_id: u32,
    volume_label: [11]u8,
    fs_type: [8]u8,
};