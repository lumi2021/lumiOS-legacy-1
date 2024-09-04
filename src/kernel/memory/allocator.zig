const std = @import("std");
const Allocator = std.mem.Allocator;
const pmm = @import("pmm.zig");

pub const page_allocator = Allocator {
    .ptr = undefined,
    .vtable = Allocator.VTable {
        .alloc = undefined,
        .free = undefined,
        .resize = undefined
    }
};
