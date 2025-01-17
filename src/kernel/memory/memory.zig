const std = @import("std");

pub const paging = @import("root").os.system.memory_paging;
pub const pmm = @import("pmm.zig");
pub const vmm = @import("vmm.zig");

pub const vaddr_from_paddr = pmm.vaddr_from_paddr;
pub const paddr_from_vaddr = pmm.paddr_from_vaddr;
pub const ptr_from_paddr = pmm.ptr_from_paddr;

pub var allocator: std.mem.Allocator = undefined;
