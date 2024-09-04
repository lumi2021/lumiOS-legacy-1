const dbg = @import("../IO/debug.zig");
const os = @import("../OS/os.zig");

pub const selector = .{
    .null = @as(u16, 0x00),
    .code64 = @as(u16, 0x08),
    .data64 = @as(u16, 0x10),
    .usercode64 = @as(u16, 0x18),
    .userdata64 = @as(u16, 0x20),
    .tss = @as(u16, 0x28),
};


pub const GDTPtr = extern struct {
    limit: u16,
    base: u64 align(2)
};

pub const GDTEntry = extern struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};


pub fn gdt_install() void {
    var gdt = &os.gdt;

    set_gdt_entry(&gdt[0], 0, 0, 0, 0);
    set_gdt_entry(&gdt[1], 0, 0xFFFFFFFF, 0x9A, 0xA0);
    set_gdt_entry(&gdt[2], 0, 0xFFFFFFFF, 0x92, 0x00);

    load_gdt(&os.gdt);
}

fn set_gdt_entry(
    gdt: *GDTEntry,
    base: u32,
    limit: u32,
    access: u8,
    granularity: u8
) void {

    gdt.base_low = @intCast(base & 0xFFFF);
    gdt.base_middle = @intCast((base >> 16) & 0xFF);
    gdt.base_high = @intCast((base >> 24) & 0xFF);

    gdt.limit_low = @intCast(limit & 0xFFFF);
    gdt.granularity = @intCast((base >> 24) & 0xFF);
    gdt.granularity |= granularity & 0xF0;
    gdt.access = access;

}

fn load_gdt(gdt: *[3]GDTEntry) void {
    var gdtp = GDTPtr {
        .limit = @intCast(@sizeOf(GDTEntry) * gdt.len - 1),
        .base = @intFromPtr(gdt)
    };

    // load gdt
    asm volatile ("lgdt (%[gdt])" :: [gdt] "r" (&gdtp));

    // use data selectors
    asm volatile ( // ## code stops here!
        \\ mov %[dsel], %%ds
        \\ mov %[dsel], %%fs
        \\ mov %[dsel], %%gs
        \\ mov %[dsel], %%es
        \\ mov %[dsel], %%ss
        :: [dsel] "rm" (selector.data64)
    );

    // use code selectors
    asm volatile (
        \\ push %[csel]
        \\ lea 1f(%%rip), %%rax
        \\ push %%rax
        \\ lretq
        \\ 1:
        :
        : [csel] "i" (selector.code64)
        : "rax"
    );
}
