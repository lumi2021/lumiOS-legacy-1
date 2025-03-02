const std = @import("std");
const os = @import("root").os;

const MemMapEntry = os.boot_info.MemoryMapEntry;

const write = os.console_write("PMM");
const st = os.stack_tracer;

pub var max_phys_mem: usize = 0;
var phys_mapping_base_unsigned: usize = undefined;
pub var kernel_size: usize = undefined;
var phys_addr_width: u8 = undefined;
var phys_mapping_limit: usize = 1 << 31;

var pmm_sizes: []const usize = undefined;
const pmm_sizes_global = blk: {
    var sizes: [41]usize = [_]usize{0} ** 41;
    for (12..53, 0..) |shift, i| {
        sizes[i] = 1 << shift;
    }
    break :blk sizes;
};
export var free_roots = [_]usize{0} ** pmm_sizes_global.len;

pub fn init(paddrwidth: u8, memmap: []*MemMapEntry) void {
    st.push(@src()); defer st.pop();

    const boot_info = @import("root").boot_info;

    phys_mapping_base_unsigned = boot_info.hhdm_address_offset;
    write.dbg("initial physical mapping base 0x{X:0>16}", .{phys_mapping_base_unsigned});

    const phys_base = boot_info.kernel_physical_base;
    const virt_base = boot_info.kernel_virtual_base;
    const kernel_end = @intFromPtr(@extern(*u64, .{ .name = "__kernel_end__" }));
    const kernel_dif = kernel_end - virt_base;

    kernel_size = std.mem.alignForwardLog2(phys_base + kernel_dif, 24);

    write.dbg("kernel physical base: 0x{X:0>16}", .{phys_base});
    write.dbg("kernel virtual base: 0x{X:0>16}", .{virt_base});
    write.dbg("kernel physical end: 0x{X:0>16}", .{kernel_end});
    write.dbg("kernel size: 0x{X}", .{kernel_size});

    phys_addr_width = paddrwidth;

    pmm_sizes = pmm_sizes_global[0..(phys_addr_width - 12)];

    for (memmap) |entry| {
        if (entry.type == .usable) {
            var base = entry.base;
            var size = entry.size;
            const end = base + size;

            if (end > max_phys_mem) max_phys_mem = end;
            if (end < kernel_size) {
                write.dbg("skipping 0x{X}..0x{X} as it is space already reserved by the kernel.", .{ base, end });
                continue;
            }
            if (end > phys_mapping_limit) {
                write.dbg("skipping 0x{X}..0x{X} as it exceeds physical mapping limit.", .{ base, end });
                continue;
            }
            if (base < kernel_size) {
                const diff = kernel_size - base;
                write.dbg("adjusting 0x{X}..0x{X} forward 0x{X} bytes to avoid initial kernel block.", .{ base, end, diff });
                base = kernel_size;
                size -= diff;
            }

            write.dbg("marking 0x{X}..0x{X} (0X{X} bytes)", .{ base, end, size });
            mark_free(base, size);
        } else {
            write.dbg("skipping 0x{X}..0x{X} as it's marked as {s}", .{entry.base, entry.base + entry.size, @tagName(entry.type)});
        }
    }
}

fn mark_free(phys_addr: usize, len: usize) void {
    st.push(@src());

    var size: usize = len;

    var a = std.mem.alignForwardLog2(phys_addr, 12);

    size -= @bitCast(a - phys_addr);
    size = std.mem.alignBackward(usize, size, pmm_sizes[0]);

    outer: while (size != 0) {
        var idx = @min(pmm_sizes.len - 1, std.math.log2_int(usize, size) - 12) + 1;
        while (idx > 0) {
            idx -= 1;
            const s = pmm_sizes[idx];

            if (size >= s and std.mem.isAligned(a, s)) {
                free_impl(a, idx);

                size -= s;
                a += s;
                continue :outer;
            }
        }

        unreachable;
    }

    st.pop();
}

pub fn alloc(len: usize) !usize {
    st.push(@src()); defer st.pop();

    const idx = std.math.log2_int_ceil(usize, len) - 12;
    if (idx >= pmm_sizes.len) return error.physical_allocation_too_large;

    const p = try alloc_impl(idx);
    @memset(ptr_from_paddr([*]u8, p)[0..len], undefined);

    return p;
}
fn alloc_impl(idx: usize) error{OutOfMemory}!usize {
    st.push(@src()); defer st.pop();

    if (free_roots[idx] == 0) {
        if (idx + 1 >= pmm_sizes.len) return error.OutOfMemory;

        var next = try alloc_impl(idx + 1);
        var next_size = pmm_sizes[idx + 1];

        const curr_size = pmm_sizes[idx];

        while (next_size > curr_size) {
            free_impl(next, idx);
            next = next + curr_size;
            next_size -= curr_size;
        }

        return next;
    } else {
        const addr = free_roots[idx];
        free_roots[idx] = ptr_from_paddr(*const usize, addr).*;

        return addr;
    }
}

pub fn free(phys_addr: usize, len: usize) void {
    st.push(@src());

    if (!std.mem.isAligned(phys_addr, pmm_sizes[0])) @panic("unaligned address to free");

    const idx = std.math.log2_int_ceil(usize, len) - 12;
    free_impl(phys_addr, idx);

    st.pop();
}
fn free_impl(phys_addr: usize, index: usize) void {
    st.push(@src());
    defer st.pop();

    ptr_from_paddr(*usize, phys_addr).* = free_roots[index];
    free_roots[index] = phys_addr;
}

pub inline fn vaddr_from_paddr(paddr: usize) usize {
    return paddr +% phys_mapping_base_unsigned;
}
pub inline fn ptr_from_paddr(Ptr: type, paddr: usize) Ptr {
    if (@as(std.builtin.TypeId, @typeInfo(Ptr)) == .Optional and paddr == 0) return null;
    return @ptrFromInt(vaddr_from_paddr(paddr));
}

pub inline fn paddr_from_ptr(ptr: anytype) usize {
    return @intFromPtr(ptr) -% phys_mapping_base_unsigned;
}
pub inline fn paddr_from_vaddr(ptr: usize) usize {
    return ptr -% phys_mapping_base_unsigned;
}

pub fn get_allocation_size(size: usize) usize {
    const idx = std.math.log2_int_ceil(usize, size) -| 12;
    return pmm_sizes[idx];
}

pub fn enlarge_mapped_physical(memmap: []*MemMapEntry, new_base: usize) void {
    st.push(@src());

    phys_mapping_base_unsigned = new_base;

    const old_limit = phys_mapping_limit;
    phys_mapping_limit = @as(usize, 1) << @intCast(phys_addr_width);

    for (memmap) |entry| {
        if (entry.type == .usable and entry.base + entry.size >= old_limit) {
            write.dbg("marking 0x{X}..0x{X} (0x{X} bytes)", .{ entry.base, entry.base + entry.size, entry.size });
            mark_free(entry.base, entry.size);
        }
    }

    st.pop();
}
