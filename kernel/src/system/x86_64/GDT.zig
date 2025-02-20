const stack_tracer = @import("../../debug/stack_trace.zig");

var tables: [3]GDTEntry = undefined;

pub const selector = .{
    .null = @as(u16, 0x00),
    .code64 = @as(u16, 0x08),
    .data64 = @as(u16, 0x10),
    .usercode64 = @as(u16, 0x18),
    .userdata64 = @as(u16, 0x20),
    .tss = @as(u16, 0x28),
};

const GDTPtr = extern struct { limit: u16, base: u64 align(2) };
const GDTEntry = extern struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};

pub fn gdt_install() void {
    stack_tracer.push(@src());

    set_gdt_entry(&tables[0], 0, 0, 0, 0);
    set_gdt_entry(&tables[1], 0, 0xFFFFFFFF, 0x9A, 0xA0);
    set_gdt_entry(&tables[2], 0, 0xFFFFFFFF, 0x92, 0x00);

    load_gdt(&tables);
    stack_tracer.pop();
}

fn load_gdt(gdt: *[3]GDTEntry) void {
    stack_tracer.push(@src());

    var gdtp = GDTPtr{ .limit = @intCast(@sizeOf(GDTEntry) * gdt.len - 1), .base = @intFromPtr(gdt) };

    // load gdt
    asm volatile ("lgdt (%[gdt])"
        :
        : [gdt] "r" (&gdtp),
    );

    // use data selectors
    asm volatile (
        \\ mov %[dsel], %%ds
        \\ mov %[dsel], %%fs
        \\ mov %[dsel], %%gs
        \\ mov %[dsel], %%es
        \\ mov %[dsel], %%ss
        :
        : [dsel] "rm" (selector.data64),
    );

    // use code selectors
    asm volatile (
        \\ push %[csel]
        \\ lea 1f(%%rip), %%rax
        \\ push %%rax
        \\ lretq
        \\ 1:
        :
        : [csel] "i" (selector.code64),
        : "rax"
    );

    stack_tracer.pop();
}
fn set_gdt_entry(gdt: *GDTEntry, base: u32, limit: u32, access: u8, granularity: u8) void {
    stack_tracer.push(@src());

    gdt.base_low = @intCast(base & 0xFFFF);
    gdt.base_middle = @intCast((base >> 16) & 0xFF);
    gdt.base_high = @intCast((base >> 24) & 0xFF);

    gdt.limit_low = @intCast(limit & 0xFFFF);
    gdt.granularity = @intCast((base >> 24) & 0xFF);
    gdt.granularity |= granularity & 0xF0;
    gdt.access = access;

    stack_tracer.pop();
}
