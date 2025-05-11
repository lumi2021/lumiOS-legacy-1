const os = @import("root").os;
const std = @import("std");

const disk = os.drivers.disk;
const partitions = os.fs.partitions;
const format = os.fs.format;
const FileSystem = partitions.FileSystem;

const print = os.console_write("partitions");
const st = os.stack_tracer;

const GPTEntry = partitions.GPTEntry;

pub fn detect_partition_fs(driver: disk.DiskEntry, entry: GPTEntry) FileSystem {
    st.push(@src()); defer st.pop();

    print.dbg("loading sector {}", .{entry.first_lba});

    var sector: [512]u8 = undefined;
    disk.read(driver, entry.first_lba, &sector) catch unreachable;

    if (std.mem.eql(u8, sector[0x1 .. 0x6], "CD001")) {
        return .iso9660;
    }
    
    return .unitialized;
}
