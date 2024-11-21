const std = @import("std");
const os = @import("../OS/os.zig");
const laligin = @import("../utils/libalign.zig");
const MemMapEntry = @import("../structures/BootInfo.zig").MemoryMapEntry;
const ctrl_reg = @import("../utils/ctrl_registers.zig");

const write = @import("../IO/debug.zig").write("PMM");

pub var kernel_size: usize = undefined;

var phys_addr_width: u8 = undefined;

pub var phys_mapping_base: usize = undefined;
pub var phys_mapping_limit: usize = 1 << 31;

const pmm_sizes_global = blk: {
    var sizes: [41]usize = [_]usize{0} ** 41;
    for (12..53, 0..) |shift, i| {
        sizes[i] = 1 << shift;
    }
    break :blk sizes;
};

var pmm_sizes: []const usize = undefined;
export var free_roots = [_]usize{0} ** pmm_sizes_global.len;
pub var max_phys_mem: usize = 0;
const log = std.log.scoped(.pmm);

pub fn init(paddrwidth: u8, memmap: []*MemMapEntry) void {
    phys_mapping_base = os.boot_info.hhdm_address_offset;
    write.dbg("initial physical mapping base 0x{X}", .{phys_mapping_base});
    
    const phys_base = os.boot_info.kernel_physical_base;
    const virt_base = os.boot_info.kernel_virtual_base;
    const kernel_end = @intFromPtr(@extern(*u64, .{ .name = "__kernel_end__" }));

    kernel_size = std.mem.alignForwardLog2(phys_base + kernel_end - virt_base, 24);
    
    write.dbg("kernel physical base 0x{X}", .{os.boot_info.kernel_physical_base});
    write.dbg("kernel virtual base 0x{X}", .{os.boot_info.kernel_virtual_base});

    write.dbg("kernel size 0x{X}", .{kernel_size});
    
    phys_addr_width = paddrwidth;
    
    pmm_sizes = pmm_sizes_global[0..(phys_addr_width - 12)];

    write.dbg("Marking pages as free...", .{});
    for (memmap) |entry| {
        if (entry.type == .usable) {
            const base = entry.base;
            const size = entry.size;
            const end = base + size;

            write.dbg("marking 0x{X}..0x{X} (0x{X} bytes)", .{ base, end, size });
            mark_free(base, size);
        }
    }
}

pub fn enlarge_mapped_physical(memmap: []*MemMapEntry, new_base: usize) void {
    phys_mapping_base = @bitCast(new_base);
    const old_limit = phys_mapping_limit;
    phys_mapping_limit = @as(usize, 1) << @intCast(phys_addr_width);
    for (memmap) |entry| {
        
        if (entry.type == .usable and entry.base + entry.size >= old_limit) {
            
            write.dbg("marking 0x{X}..0x{X} (0x{X} bytes)", .{ entry.base, entry.base + entry.size, entry.size });
            mark_free(entry.base, entry.size);
        }
    }
}

pub fn ptr_from_physaddr(Ptr: type, paddr: usize) Ptr {
    if (@as(std.builtin.TypeId, @typeInfo(Ptr)) == .Optional and paddr == 0) {
        return null;
    }
    return @ptrFromInt(paddr +% phys_mapping_base);
}

pub fn physaddr_from_ptr(ptr: anytype) usize {
    return @intFromPtr(ptr) -% phys_mapping_base;
}

fn alloc_impl(idx: usize) error{OutOfMemory}!usize {
    
    if (free_roots[idx] == 0) {
        
        if (idx + 1 >= pmm_sizes.len) {
            return error.OutOfMemory;
        }

        var next = try alloc_impl(idx + 1);
        var next_size = pmm_sizes[idx + 1];

        const curr_size = pmm_sizes[idx];

        while (next_size > curr_size) {
            free_impl(next, idx);
            next += curr_size;
            next_size -= curr_size;
        }

        return next;
    } else {
        const addr = free_roots[idx];
        
        free_roots[idx] = ptr_from_physaddr(*const usize, addr).*;
        return addr;
    }
}

fn free_impl(phys_addr: usize, index: usize) void {
    
    ptr_from_physaddr(*usize, phys_addr).* = free_roots[index];
    free_roots[index] = phys_addr;
}


pub fn alloc(len: usize) !usize {
    
    const idx = std.math.log2_int_ceil(usize, len) - 12;
    if (idx >= pmm_sizes.len) {
        return error.physical_allocation_too_large;
    }
    
    const p = try alloc_impl(idx);
    @memset(ptr_from_physaddr([*]u8, p)[0..len], undefined);
    return p;
}

pub fn get_allocation_size(size: usize) usize {
    const idx = std.math.log2_int_ceil(usize, size) -| 12;
    return pmm_sizes[idx];
}


pub fn free(phys_addr: usize, len: usize) void {
    if (!std.mem.isAligned(phys_addr, pmm_sizes[0])) {
        @panic("unaligned address to free");
    }

    const idx = std.math.log2_int_ceil(usize, len) - 12;
    free_impl(phys_addr, idx);
}


fn mark_free(phys_addr: usize, len: usize) void {
    var sz: usize = len;
    var a = std.mem.alignForwardLog2(phys_addr, 12);
    
    sz -= @bitCast(a - phys_addr);
    sz = std.mem.alignBackward(usize, sz, pmm_sizes[0]);

    outer: while (sz != 0) {
        
        var idx = @min(pmm_sizes.len - 1, std.math.log2_int(usize, sz) - 12) + 1;
        while (idx > 0) {
            idx -= 1;
            const s = pmm_sizes[idx];
            
            if (sz >= s and std.mem.isAligned(a, s)) {
                
                free_impl(a, idx);
                
                sz -= s;
                a += s;
                continue :outer;
            }
        }
        
        unreachable;
    }
}