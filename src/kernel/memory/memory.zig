const std = @import("std");

pub const paging = @import("root").os.system.memory_paging;
pub const pmm = @import("pmm.zig");
pub const vmm = @import("vmm.zig");

pub var allocator: std.mem.Allocator = undefined;
