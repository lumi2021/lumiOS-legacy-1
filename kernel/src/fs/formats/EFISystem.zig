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

    print.dbg("loading sector {}", .{entry.first_lba});

    var sector: [512]u8 = undefined;
    disk.read(driver, entry.first_lba, &sector);


    if (std.mem.eql(u8, sector[54 .. 60], "FAT12 ")) {
        print.log("Partition is FAT12!", .{});
        return .FAT12;
    }
    
    return .unitialized;
}
