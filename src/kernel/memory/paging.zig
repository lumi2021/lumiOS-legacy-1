pub const entries = @import("page_table_entry.zig");
const std = @import("std");

const cpuid = @import("../utils/cpuid.zig");
const pmm = @import("pmm.zig");
const ctrl_registers = @import("../utils/ctrl_registers.zig");

const write = @import("../IO/debug.zig").write("Paging");

pub const PagingFeatures = packed struct {
    maxphyaddr: u8,
    linear_address_width: u8,
    five_level_paging: bool,
    gigabyte_pages: bool,
    global_page_support: bool,
};

pub fn enumerate_paging_features() PagingFeatures {
    const addresses = cpuid.cpuid(.extended_address_info, {}).address_size_info;
    const feats_base = cpuid.cpuid(.type_fam_model_stepping_features, {});
    const feats_ext = cpuid.cpuid(.extended_fam_model_stepping_features, {});
    const flags = cpuid.cpuid(.feature_flags, {});
    features = PagingFeatures{
        .maxphyaddr = addresses.physical_address_bits,
        .linear_address_width = addresses.virtual_address_bits,
        .five_level_paging = flags.flags2.la57,
        .gigabyte_pages = feats_ext.features2.pg1g,
        .global_page_support = feats_base.features.pge,
    };
    return features;
}

pub inline fn Table(Entry: type) type {
    // should always be 512 but easier to think of as one 4K page worth of entries
    return *[4096 / 8]Entry;
}

// the base address of the top level page table
pub var pgtbl: ?Table(entries.PML45E) = null;
var root_physaddr: usize = undefined;
pub var using_5_level_paging: bool = false;
pub var features: PagingFeatures = undefined;

const PageFaultErrorCode = packed struct(usize) {
    p: enum(u1) {
        non_present = 0,
        page_protection_violation = 1,
    },
    wr: enum(u1) {
        read = 0,
        write = 1,
    },
    us: enum(u1) {
        supervisor = 0,
        user = 1,
    },
    rsvd: bool,
    id: enum(u1) {
        data = 0,
        instruction_fetch = 1,
    },
    protection_key_violation: bool,
    shadow_stack_access: bool,
    hlat: bool,
    _1: u7 = 0,
    sgx: bool,
    _2: @Type(.{ .Int = .{ .signedness = .unsigned, .bits = @bitSizeOf(usize) - 16 } }) = 0,
};

pub const SplitPagingAddr = packed struct(isize) {
    byte: u12,
    page: u9,
    table: u9,
    directory: u9,
    dirptr: u9,
    pml4: i9,
    _: u7,

    pub fn format(self: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        try fmt.print("0x{X:0>16} {b:0>9}:{b:0>9}:{b:0>9}:{b:0>9}:{b:0>9}:{b:0>12}", .{ @as(usize, @bitCast(self.*)), @as(u9, @bitCast(self.pml4)), self.dirptr, self.directory, self.table, self.page, self.byte });
    }
};

pub const PageSize = enum {
    normal,
    large,
    huge,
};

// maps a contiguous region of virtual memory to a contiguous region of physical memory
// this function uses the largest possible page sizes within alignment and compatability limits
// though the same caveats about huge pages and free physical memory apply to this function as to map_page
pub fn map_range(base_phys: usize, base_linear: usize, length: usize) !void {
    var pa = base_phys;
    var la = base_linear;
    var sz = length;
    if (!std.mem.isAlignedLog2(pa, 12) or !std.mem.isAlignedLog2(la, 12) or !std.mem.isAlignedLog2(sz, 12)) {
        return error.misaligned_mapping_range;
    }
    while (sz > 0) {
        if (std.mem.isAlignedLog2(pa, 30) and std.mem.isAlignedLog2(la, 30) and std.mem.isAlignedLog2(sz, 30) and sz >= 1 << 30) {
            try map_page(pa, la, .huge);
            sz -= 1 << 30;
            pa += 1 << 30;
            la += 1 << 30;
        } else if (std.mem.isAlignedLog2(pa, 21) and std.mem.isAlignedLog2(la, 21) and std.mem.isAlignedLog2(sz, 21) and sz >= 1 << 21) {
            try map_page(pa, la, .large);
            sz -= 1 << 21;
            pa += 1 << 21;
            la += 1 << 21;
        } else if (sz >= 1 << 12) {
            try map_page(pa, la, .normal);
            sz -= 1 << 12;
            pa += 1 << 12;
            la += 1 << 12;
        }
    }
}

pub noinline fn map_page(phys_addr: usize, linear_addr: usize, page_size: PageSize) !void {
    // write.dbg("mapping {x:0>16} to {x:0>16} ({s})", .{ linear_addr, phys_addr, @tagName(page_size) });
    // this method takes a physical address meaning the block is already mapped
    const alignment: u8 = switch (page_size) {
        .normal => 12,
        .large => 21,
        .huge => 30,
    };
    // double check the alignment of the addresses we got
    if (!std.mem.isAlignedLog2(linear_addr, alignment)) {
        write.dbg("linear address 0x{X} misaligned for {s} page", .{ linear_addr, @tagName(page_size) });
        return error.misaligned_page_linear_addr;
    }
    if (!std.mem.isAlignedLog2(phys_addr, alignment)) {
        write.dbg("physical address 0x{X} misaligned for {s} page", .{ phys_addr, @tagName(page_size) });
        return error.misaligned_page_physical_addr;
    }
    const split: SplitPagingAddr = @bitCast(linear_addr);
    const pml4: Table(entries.PML45E) = if (using_5_level_paging) b: {
        const pml5 = try get_or_create_root_table();
        var entry: *entries.PML45E = &pml5[@as(u9, @bitCast(split.pml4))];
        if (entry.present) {
            break :b pmm.ptr_from_physaddr(Table(entries.PML45E), entry.get_phys_addr());
        }
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.present = true;
        break :b try create_page_table(entries.PML45E, entry);
    } else b: {
        if (split.pml4 != 0 and split.pml4 != -1) {
            std.debug.panic("Cannot map address {} without 5-level paging!", .{split});
        }
        break :b try get_or_create_root_table();
    };
    const pdpt: Table(entries.PDPTE) = b2: {
        var entry: *entries.PML45E = &pml4[split.dirptr];
        if (entry.present) {
            break :b2 pmm.ptr_from_physaddr(Table(entries.PDPTE), entry.get_phys_addr());
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.present = true;
        break :b2 try create_page_table(entries.PDPTE, entry);
    };
    if (features.gigabyte_pages and page_size == .huge) {
        // gigabyte pages are supported
        var entry: *entries.PDPTE = &pdpt[split.directory];
        if (entry.present) {
            write.dbg("huge page already mapped for 0x{X}", .{linear_addr});
            return error.address_already_mapped;
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.page_size = true;
        entry.set_phys_addr(phys_addr);
        entry.present = true;
        return;
    } else if (page_size == .huge) {
        // write.dbg("no huge page support, mapping a directory of large pages instead", .{});
        // no 1g page support so recurse and map 512 large pages. the higher level tables should all short-circuit here.
        for (0..512) |table| {
            const new_addr: usize = linear_addr + (table << 21);
            try map_page(phys_addr + (table << 21), new_addr, .large);
        }
        return;
    }
    const directory: Table(entries.PDE) = b3: {
        var entry: *entries.PDPTE = &pdpt[split.directory];
        if (entry.present) {
            break :b3 pmm.ptr_from_physaddr(Table(entries.PDE), entry.get_phys_addr());
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.page_size = false;
        entry.present = true;
        break :b3 try create_page_table(entries.PDE, entry);
    };
    if (page_size == .large) {
        var entry: *entries.PDE = &directory[split.table];
        if (entry.present) {
            write.dbg("large page already mapped for 0x{X}", .{linear_addr});
            return error.address_already_mapped;
        }
        // write.dbg("agony and sorrow {X} {X}", .{ phys_addr, phys_addr >> 21 });
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.page_size = true;
        entry.set_phys_addr(phys_addr);
        entry.present = true;
        return;
    }
    const table: Table(entries.PTE) = b4: {
        var entry: *entries.PDE = &directory[split.table];
        if (entry.present) {
            break :b4 pmm.ptr_from_physaddr(Table(entries.PTE), entry.get_phys_addr());
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.page_size = false;
        entry.present = true;
        break :b4 try create_page_table(entries.PTE, entry);
    };
    {
        var entry: *entries.PTE = &table[split.page];
        if (entry.present) {
            return error.address_already_mapped;
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.set_phys_addr(phys_addr);
        entry.present = true;
    }
}

var cr3_new: ctrl_registers.ControlRegisterValueType(.cr3) = undefined;

fn get_or_create_root_table() !Table(entries.PML45E) {
    if (pgtbl) |tbl| {
        return tbl;
    }
    @setCold(true);
    cr3_new = ctrl_registers.read(.cr3);
    pgtbl = try create_page_table(entries.PML45E, &cr3_new);
    root_physaddr = cr3_new.get_phys_addr();
    write.dbg("page table root allocated at physical 0x{X}", .{root_physaddr});
    return pgtbl.?;
}

pub fn load_pgtbl() void {
    write.dbg("setting page tables", .{});
    ctrl_registers.write(.cr3, cr3_new);
}

pub fn finalize_and_fix_root() void {
    pgtbl = pmm.ptr_from_physaddr(Table(entries.PML45E), root_physaddr);
}


fn create_page_table(Entry: type, entry: anytype) !Table(Entry) {
    const Ret = Table(Entry);
    const tbl_physaddr = try pmm.alloc(@sizeOf(std.meta.Child(Ret)));
    entry.set_phys_addr(tbl_physaddr);
    const ptr = pmm.ptr_from_physaddr(Ret, tbl_physaddr);
    @memset(std.mem.asBytes(ptr), 0);
    return ptr;
}

test {
    @import("std").testing.refAllDecls(entries);
    @import("std").testing.refAllDecls(@This());
}