const os = @import("root").os;
const std = @import("std");

const fs = os.fs;
const disk = os.drivers.disk;
const format = os.fs.format;

const print = os.console_write("partitions");
const st = os.stack_tracer;

pub fn analyze_partition(dev: disk.DiskEntry, node: *fs.FsNode, start: usize, end: usize) void {
    st.push(@src()); defer st.pop();
    
    _ = dev;
    _ = node;
    _ = start;
    _ = end;
}

