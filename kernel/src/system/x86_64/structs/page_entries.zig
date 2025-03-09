pub const PageMeta = packed struct(u7) {
    /// if present is false and reserved is true then a page fault to this page should lazily obtain and zero a physical
    /// page. if both present and reserved is false, and the physical address of the page is nonzero then the page is
    /// currently paged out to disk somewhere identified by that address. if the address is zero and both reserved and
    /// present are false then a page fault to this page is always an illegal access to unallocated memory
    reserved: bool,
    _: u6,
};

pub const PageMapEntry = packed struct(u64) {
    present: bool,
    writable: bool,
    user_mode_accessible: bool,
    pwt: bool,
    pcd: bool,
    accessed: bool,
    _ignored1: u6 = 0,
    physaddr: u40,
    meta: PageMeta,
    _ignored2: u4 = 0,
    xd: bool,

    const physaddr_mask = makeTruncMask(PageMapEntry, "physaddr");
    pub fn get_phys_addr(self: PageMapEntry) usize {
        return @as(u64, @bitCast(self)) & physaddr_mask;
    }
    pub fn set_phys_addr(self: *PageMapEntry, addr: usize) void {
        self.physaddr = @truncate(addr >> 12);
    }
};

pub const PageDirectoryPointerTableEntry = packed struct(u64) {
    present: bool,
    writable: bool,
    user_mode_accessible: bool,
    pwt: bool,
    pcd: bool,
    accessed: bool,
    dirty: bool,
    page_size: bool,
    global: bool,
    _ignored1: u3 = 0,
    physaddr: packed union {
        gb_page: packed struct(u51) {
            pat: bool,
            _ignored: u17 = 0,
            physaddr: u22, // must be left shifted 30 to get true addr
            meta: PageMeta,
            protection_key: u4, // ignored if pointing to page directory
        },
        pd_ptr: packed struct(u51) {
            addr: u40, // must be left shifted 12 to get true addr
            meta: PageMeta,
            _ignored2: u4 = 0,
        },
    },
    xd: bool,

    pub fn get_phys_addr(self: @This()) usize {
        if (self.page_size) {
            // 1gb page
            return @as(u52, @intCast(self.physaddr.gb_page.physaddr)) << 30;
        } else {
            return @as(u52, @intCast(self.physaddr.pd_ptr.addr)) << 12;
        }
    }
    pub fn set_phys_addr(self: *@This(), addr: usize) void {
        if (self.page_size) {
            // 1gb page
            self.physaddr.gb_page.physaddr = @truncate(addr >> 30);
        } else {
            self.physaddr.pd_ptr.addr = @truncate(addr >> 12);
        }
    }
};

pub const PageDirectoryEntry = packed struct(u64) {
    present: bool,
    writable: bool,
    user_mode_accessible: bool,
    pwt: bool,
    pcd: bool,
    accessed: bool,
    dirty: bool,
    page_size: bool,
    global: bool,
    _ignored1: u3 = 0,
    physaddr: packed union {
        mb_page: packed struct(u51) {
            pat: bool,
            _ignored: u8 = 0,
            physaddr: u31, // must be left shifted 21 to get true addr
            meta: PageMeta,
            protection_key: u4, // ignored if pointing to page table
        },
        pd_ptr: packed struct(u51) {
            addr: u40, // must be left shifted 12 to get true addr
            meta: PageMeta,
            _ignored2: u4 = 0,
        },
    },
    xd: bool,

    pub fn get_phys_addr(self: PageDirectoryEntry) usize {
        if (self.page_size) {
            // 2mb page
            return @as(u52, @intCast(self.physaddr.mb_page.physaddr)) << 21;
        } else {
            return @as(u52, @intCast(self.physaddr.pd_ptr.addr)) << 12;
        }
    }
    pub fn set_phys_addr(self: *PageDirectoryEntry, addr: usize) void {
        if (self.page_size) {
            // 2mb page
            self.physaddr.mb_page.physaddr = @truncate(addr >> 21);
        } else {
            self.physaddr.pd_ptr.addr = @truncate(addr >> 12);
        }
    }
};

pub const PageTableEntry = packed struct(u64) {
    present: bool,
    writable: bool,
    user_mode_accessible: bool,
    pwt: bool,
    pcd: bool,
    accessed: bool,
    dirty: bool,
    pat: bool,
    global: bool,
    _ignored1: u3 = 0,
    physaddr: u40, // must be left shifted 12 to get true addr
    meta: PageMeta,
    protection_key: u4, // may be ignored if disabled
    xd: bool,

    const physaddr_mask = makeTruncMask(PageTableEntry, .physaddr);
    pub fn get_phys_addr(self: PageTableEntry) usize {
        return @as(u64, @bitCast(self)) & physaddr_mask;
    }
    pub fn set_phys_addr(self: *PageTableEntry, addr: usize) void {
        self.physaddr = @truncate(addr >> 12);
    }
};

// generates a mask to isolate a field of a packed struct while keeping it shifted relative to its bit offset in the struct.
// the field's value is effectively left shifted by its bit offset in the struct and bits outside the field are masked out
fn makeTruncMask(comptime T: type, comptime field: []const u8) @Type(.{ .@"int" = .{ .signedness = .unsigned, .bits = @bitSizeOf(T) } }) {
    const offset = @bitOffsetOf(T, field);
    const size = @bitSizeOf(@TypeOf(@field(@as(T, undefined), field)));

    const size_mask = (1 << size) - 1;
    return size_mask << offset;
}
