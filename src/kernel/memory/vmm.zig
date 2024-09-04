const std = @import("std");
const dbg = @import("../IO/debug.zig");
const pmm = @import("pmm.zig");
const paging = @import("paging.zig");
const ctrl_registers = @import("../utils//ctrl_registers.zig");

const MemoryMapEntry = @import("../structures/BootInfo.zig").MemoryMapEntry;

const idmap_base_4lvl: isize = -1 << 45;
const idmap_base_5lvl: isize = -1 << 53;

const log = std.log.scoped(.vmm);

var phys_mapping_range_bits: u6 = undefined;

pub fn init(memmap: []MemoryMapEntry) !void {

    paging.using_5_level_paging = paging.features.five_level_paging and ctrl_registers.read(.cr4).la57;
    const idmap_base = if (paging.using_5_level_paging) idmap_base_5lvl else idmap_base_4lvl;

    dbg.printf("mapping all phys mem at 0x{X}\r\n", .{@as(usize, @bitCast(idmap_base))});
    phys_mapping_range_bits = if (paging.using_5_level_paging) @min(paging.features.maxphyaddr, 48) else @min(paging.features.maxphyaddr, 39);
    dbg.printf("phys mapping range of {d} bits\r\n", .{phys_mapping_range_bits});
    try paging.map_range(0, idmap_base, @as(usize, 1) << phys_mapping_range_bits);
    dbg.printf("mapping bottom {X} at 0x{X}\r\n", .{ pmm.kernel_size, @as(usize, @bitCast(@as(isize, -1 << 31))) });
    try paging.map_range(0, -1 << 31, pmm.kernel_size);
    dbg.printf("mapping bottom 4M at 0\r\n", .{});
    try paging.map_range(0, 0, 1 << 22);

    //dump_paging_debug();

    dbg.printf("finished page tables, applying\r\n", .{});
    
    paging.load_pgtbl();

    dbg.printf("pages mapped, relocating and enlarging pmm\r\n", .{});
    pmm.enlarge_mapped_physical(memmap, idmap_base);
    dbg.printf("high physical memory given to pmm\r\n", .{});
    paging.finalize_and_fix_root();
}

pub fn phys_from_virt(virt: anytype) usize {
    // if the address is in the physically mapped block then just do the fast math
    if (virt > pmm.phys_mapping_base and @log2(virt - pmm.phys_mapping_base) <= phys_mapping_range_bits) {
        return pmm.physaddr_from_ptr(@as(*anyopaque, @ptrFromInt(virt)));
    }

    // otherwise actually trace the page structures
    std.debug.assert(@TypeOf(virt) == usize or @TypeOf(virt) == isize);
    const split: paging.SplitPagingAddr = @bitCast(virt);
    const dirptr = paging.pgtbl.?[split.dirptr].get_phys_addr();
    const directory = pmm.ptr_from_physaddr(paging.Table(paging.entries.PDPTE), dirptr)[split.directory];
    if (directory.page_size) {
        // gig page
        return directory.get_phys_addr() + @as(usize, @bitCast(virt)) & ((1 << 30) - 1);
    }
    const direntry = pmm.ptr_from_physaddr(paging.Table(paging.entries.PDE), directory.get_phys_addr())[split.table];
    if (direntry.page_size) {
        // 2mb page
        return direntry.get_phys_addr() + @as(usize, @bitCast(virt)) & ((1 << 21) - 1);
    }
    // regular-ass 4k page
    const page = pmm.ptr_from_physaddr(paging.Table(paging.entries.PTE), direntry.get_phys_addr())[split.page];
    return page.get_phys_addr() + split.byte;
}

pub const raw_page_allocator = struct {
    vtab: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .free = free },

    pub fn allocator(self: *const @This()) std.mem.Allocator {
        return .{
            .ptr = undefined,
            .vtable = &self.vtab,
        };
    }

    fn alloc(_: *anyopaque, len: usize, ptr_align: u8, _: usize) ?[*]u8 {
        const alloc_len = pmm.get_allocation_size(@max(@as(usize, 1) << @truncate(ptr_align), len));

        const ptr = pmm.ptr_from_physaddr([*]u8, pmm.alloc(alloc_len) catch |err| {
            switch (err) {
                error.OutOfMemory => return null,
                else => {
                    std.debug.panicExtra(@errorReturnTrace(), @returnAddress(), "PMM allocator: {}", .{err});
                },
            }
        });

        return ptr;
    }

    fn resize(_: *anyopaque, old_mem: []u8, old_align: u8, new_size: usize, ret_addr: usize) bool {
        const old_alloc = pmm.get_allocation_size(@max(old_mem.len, old_align));

        const addr: usize = @intFromPtr(old_mem.ptr);
        const base_vaddr = pmm.phys_mapping_base;
        const paddr: usize = addr - @as(usize, @bitCast(base_vaddr));

        if (new_size == 0) {
            free(undefined, old_mem, old_align, ret_addr);
            return true;
        } else {
            const new_alloc = pmm.get_allocation_size(@max(new_size, old_align));

            if (new_alloc > old_alloc) {
                return false;
            }

            var curr_alloc = old_alloc;
            while (new_alloc < curr_alloc) {
                pmm.free(paddr + curr_alloc / 2, curr_alloc / 2);
                curr_alloc /= 2;
            }

            return true;
        }
    }

    fn free(_: *anyopaque, old_mem: []u8, old_align: u8, _: usize) void {
        const old_alloc = pmm.get_allocation_size(@max(old_mem.len, old_align));

        const addr = @intFromPtr(old_mem.ptr);
        const base_vaddr: usize = @bitCast(pmm.phys_mapping_base);
        const paddr = addr - base_vaddr;

        pmm.free(paddr, old_alloc);
    }
}{};

pub var gpa: std.heap.GeneralPurposeAllocator(.{ .thread_safe = false }) = .{ .backing_allocator = raw_page_allocator.allocator() };

pub fn alloc_page() !*anyopaque {
    const paddr = try pmm.alloc(1 << 12);
    // todo allocate outside of the big map range but for kernel-mode stuff that isnt too important
    // todo page swapping. again not as important for kernel-mode stuff
    return pmm.ptr_from_physaddr(*anyopaque, paddr);
}

pub fn free_page(ptr: *const anyopaque) void {
    pmm.free(phys_from_virt(@intFromPtr(ptr)), 1 << 12);
}

fn dump_paging_debug() void {
    const addr: usize = 0xffffe000fd000000;
    const p = addr - @as(usize, @bitCast(idmap_base_4lvl));
    const split: paging.SplitPagingAddr = @bitCast(addr);
    dbg.printf("address to map: 0x{X:0>16} {b:0>9}:{b:0>9}:{b:0>9}:{b:0>9}:{b:0>9}:{b:0>12}\r\n", .{ addr, @as(u9, @bitCast(split.pml4)), split.dirptr, split.directory, split.table, split.page, split.byte });
    dbg.printf("expect phys addr: {X}:{X:0>3}\r\n", .{ p >> 12, p & 4095 });
    const dirptr = paging.pgtbl.?[split.dirptr].get_phys_addr();
    dbg.printf("dirptr[{d}] at 0x{X}\r\n", .{ split.dirptr, dirptr });
    const directory = pmm.ptr_from_physaddr(paging.Table(paging.entries.PDPTE), dirptr)[split.directory].get_phys_addr();
    dbg.printf("directory[{d}] at 0x{X}\r\n", .{ split.directory, directory });
    const direntry = pmm.ptr_from_physaddr(paging.Table(paging.entries.PDE), directory)[split.table];
    if (direntry.page_size) {
        dbg.printf("2mb page[{d}] at 0x{X}\r\n", .{ split.table, direntry.get_phys_addr() });
    } else {
        const table = direntry.get_phys_addr();
        dbg.printf("table[{d}] at 0x{X}\r\n", .{ split.table, table });
        dbg.printf("4k page[{d}] at 0x{X}\r\n", .{ split.page, pmm.ptr_from_physaddr(paging.Table(paging.entries.PTE), table)[split.page].get_phys_addr() });
    }
}
