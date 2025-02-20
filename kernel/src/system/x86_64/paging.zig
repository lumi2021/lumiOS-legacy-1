const std = @import("std");
const os = @import("root").os;
const page_entries = os.system.memory_paging_entries;
const pmm = os.memory.pmm;

const cpuid = @import("cpuid.zig");
const ctrl_regs = @import("ctrl_registers.zig");

const PTE = page_entries.PageTableEntry;
const PDE = page_entries.PageDirectoryEntry;
const PDPTE = page_entries.PageDirectoryPointerTableEntry;
const PML45E = page_entries.PageMapEntry;

pub var using_5_level_paging = false;
pub var page_table: ?Table(PML45E) = null;
var root_physaddr: usize = undefined;

const write = os.console_write("Paging");
const st = os.stack_tracer;

pub var features: PagingFeatures = undefined;
pub const PagingFeatures = struct {
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

pub const PageSize = enum {
    normal,
    large,
    huge,
};

pub inline fn Table(Entry: type) type {
    return *[4096 / 8]Entry;
}

pub fn map_range(pbase: usize, vbase: usize, len: usize) !void {
    st.push(@src());

    var pa = pbase;
    var la = vbase;
    var sz = len;

    if (
        !std.mem.isAlignedLog2(pa, 12)
     or !std.mem.isAlignedLog2(@bitCast(la), 12)
     or !std.mem.isAlignedLog2(sz, 12)
    ) {
        st.pop();
        return error.misaligned_mapping_range;
    }

    while (sz > 0) {
        if (
            std.mem.isAlignedLog2(pa, 30)
        and std.mem.isAlignedLog2(@bitCast(la), 30)
        and std.mem.isAlignedLog2(sz, 30)
        and sz >= 1 << 30
        ) {
            try map_page(pa, la, .huge);
            sz -= 1 << 30;
            pa += 1 << 30;
            la += 1 << 30;
        } else if (
            std.mem.isAlignedLog2(pa, 21)
        and std.mem.isAlignedLog2(@bitCast(la), 21)
        and std.mem.isAlignedLog2(sz, 21)
        and sz >= 1 << 21
        ) {
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

    st.pop();
}

pub fn map_page(paddr: usize, vaddr: usize, page_size: PageSize) !void {
    st.push(@src());

    const split: SplitPagingAddr = @bitCast(vaddr);

    const pml4: Table(PML45E) = if (using_5_level_paging) b: {
        const pml5 = try get_or_create_root_table();
        var entry: *PML45E = &pml5[@as(u9, @bitCast(split.pml4))];
        if (entry.present) {
            break :b pmm.ptr_from_paddr(Table(PML45E), entry.get_phys_addr());
        }
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.present = true;

        break :b try create_page_table(PML45E, entry);
    } else b: {
        if (split.pml4 != 0 and split.pml4 != -1) write.err("Cannot map address {} without 5-level paging!", .{split});
        break :b try get_or_create_root_table();
    };

    const page_dir: Table(PDPTE) = b2: {
        var entry: *PML45E = &pml4[split.dirptr];
        if (entry.present) break :b2 pmm.ptr_from_paddr(Table(PDPTE), entry.get_phys_addr());

        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.present = true;

        break :b2 try create_page_table(PDPTE, entry);
    };

    if (features.gigabyte_pages and page_size == .huge) {

        // gigabyte pages are supported
        var entry: *PDPTE = &page_dir[split.directory];
        if (entry.present) {
            write.dbg("huge page already mapped to 0x{X}", .{vaddr});
            return error.address_already_mapped;
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.page_size = true;
        entry.set_phys_addr(paddr);
        entry.present = true;
        st.pop();
        return;

    } else if (page_size == .huge) {

        for (0..512) |table| {
            const new_v_addr = vaddr + (table << 21);
            const new_p_addr = paddr + (table << 21);
            try map_page(new_p_addr, new_v_addr, .large);
        }
        st.pop();
        return;

    }

    const directory: Table(PDE) = b3: {
        var entry: *PDPTE = &page_dir[split.directory];
        if (entry.present) break :b3 pmm.ptr_from_paddr(Table(PDE), entry.get_phys_addr());
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.page_size = false;
        entry.present = true;
        break :b3 try create_page_table(PDE, entry);
    };

    if (page_size == .large) {

        var entry: *PDE = &directory[split.table];
        if (entry.present) {
            write.dbg("large page already mapped for 0x{X}", .{vaddr});
            st.pop();
            return error.address_already_mapped;
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.page_size = true;
        entry.set_phys_addr(paddr);
        entry.present = true;
        return;

    }

    const table: Table(PTE) = b4: {
        var entry: *PDE = &directory[split.table];
        if (entry.present) {
            break :b4 pmm.ptr_from_paddr(Table(PTE), entry.get_phys_addr());
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.page_size = false;
        entry.present = true;
        break :b4 try create_page_table(PTE, entry);
    };
    {
        var entry: *PTE = &table[split.page];
        if (entry.present) {
            st.pop();
            return error.address_already_mapped;
        }
        entry.* = @bitCast(@as(usize, 0));
        entry.writable = true;
        entry.xd = false;
        entry.user_mode_accessible = split.pml4 < 0;
        entry.set_phys_addr(paddr);
        entry.present = true;
    }

    st.pop();
}

fn create_page_table(Entry: type, entry: anytype) !Table(Entry) {
    st.push(@src());

    const Ret = Table(Entry);
    const tbl_physaddr = try pmm.alloc(@sizeOf(std.meta.Child(Ret)));
    entry.set_phys_addr(tbl_physaddr);
    const ptr = pmm.ptr_from_paddr(Ret, tbl_physaddr);
    @memset(std.mem.asBytes(ptr), 0);
    
    st.pop();
    return ptr;
}

var cr3_new: ctrl_regs.ControlRegisterValueType(.cr3) = undefined;

fn get_or_create_root_table() !Table(PML45E) {
    st.push(@src());

    if  (page_table) |table| {
        st.pop();
        return table;
    }

    cr3_new = ctrl_regs.read(.cr3);
    page_table = try create_page_table(PML45E, &cr3_new);
    write.dbg("page table root allocated at phys 0x{X}", .{cr3_new.get_phys_addr()});
    root_physaddr = cr3_new.get_phys_addr();

    st.pop();
    return page_table.?;
}

pub fn load_pgtbl() void {
    st.push(@src());
    ctrl_regs.write(.cr3, cr3_new);
    st.pop();
}

pub fn finalize() void {
    page_table = pmm.ptr_from_paddr(Table(PML45E), root_physaddr);
}

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
