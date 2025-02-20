pub var entries: [256]IDTEntry = undefined;

pub const IDTEntry = extern struct {
    offset_low: u16,
    selector: u16,
    zero: u8,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    zeroes: u32,
};
pub const IDTPtr = extern struct {
    limit: u16,
    base: u64 align(2),
};

pub fn idt_install() void {
    load_idt(&entries);
}

fn load_idt(idt: *[256]IDTEntry) void {
    var idtp = IDTPtr{ .limit = @intCast(@sizeOf(IDTEntry) * 256 - 1), .base = @intFromPtr(idt) };

    asm volatile ("lidt (%[idtp])"
        :
        : [idtp] "r" (&idtp),
    );
}
pub fn set_entry(self: *[256]IDTEntry, num: u8, b: *const fn () callconv(.Naked) void, s: u16, f: u8) void {
    const ie = &self[num];

    const baseAsInt = @intFromPtr(b);
    ie.offset_low = @intCast(baseAsInt & 0xFFFF);
    ie.selector = s;
    ie.zero = 0;
    ie.type_attr = f;
    ie.offset_mid = @intCast((baseAsInt >> 16) & 0xFFFF);
    ie.offset_high = @intCast(baseAsInt >> 32);
}
