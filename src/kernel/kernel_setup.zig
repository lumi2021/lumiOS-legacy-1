const std = @import("std");
const io = @import("IO/port_io.zig");
const alloc = @import("memory/allocator.zig");
const os = @import("OS/os.zig");
const cpuid = @import("utils/cpuid.zig");
const dbg = @import("IO/debug.zig");

const paging = @import("memory/paging.zig");

const gdt_ops = @import("./structures/GDT.zig");
const idt_ops = @import("./structures/IDT.zig");

const GDT = gdt_ops.GDT;
const GDTR = gdt_ops.GDTPtr;

const IDTEntry = idt_ops.IDTEntry;
const IDTR = idt_ops.IDTPtr;

const pmm = @import("./memory/pmm.zig");
const vmm = @import("./memory/vmm.zig");

const ZigAllocator = std.mem.Allocator;

const task_man = @import("task_manager.zig");

const interrupt_table = @import("interrupt_table.zig");


const vtab = ZigAllocator.VTable {
            .alloc = malloc,
            .free = free,
            .resize = reloc
        };

pub fn init_setup() void {
    
    dbg.puts("setupping GDT...\r\n");
    setup_GDT();

    dbg.puts("setupping IDT...\r\n");
    setup_IDT();

    const paging_feats = paging.enumerate_paging_features();

    dbg.printf("physical addr width: {d} (0x{X} pages)\r\n",
    .{ paging_feats.maxphyaddr, @as(u64, 1) << @truncate(paging_feats.maxphyaddr - 12) });
    dbg.printf("linear addr width {d}\r\n", .{paging_feats.linear_address_width});
    
    dbg.puts("setupping PMM...\r\n");
    pmm.init(paging_feats.maxphyaddr, os.boot_info.memory_map.*);
    dbg.puts("initialized lower phys mem\r\n");

    // as vmm is not working, i will disable it for now :3
    //dbg.puts("setupping VMM...\r\n");
    //vmm.init(os.boot_info.memory_map.*) catch @panic("Error during VMM init!");

    dbg.puts("setupping Allocator...\r\n");
    setup_Allocator();

    dbg.puts("setupping Task Manager...\r\n");
    setup_Task_manager();

    dbg.puts("starting Schedue...\r\n");
    setup_timer();

}


pub inline fn setup_Allocator() void {
    os.allocator = ZigAllocator {
        .ptr = undefined,
        .vtable = &vtab
    };
}

fn malloc(_: *anyopaque, len: usize, _: u8, _: usize) ?[*]u8 {
    return @as([*]u8, @ptrFromInt(pmm.alloc(len) catch 0));
}
fn free(_: *anyopaque, buf: []u8, _: u8, _: usize) void {
    pmm.free(@intFromPtr(buf.ptr), buf.len);
}
fn reloc(_: *anyopaque, buf: []u8, _: u8, new_len: usize, _: usize) bool {
    _ = buf;
    _ = new_len;

    return false;
}

pub inline fn setup_Task_manager() void {
    task_man.init();
}

pub inline fn setup_GDT() void {
    gdt_ops.gdt_install();
}

pub inline fn setup_IDT() void {
    idt_ops.idt_install();
    interrupt_table.init_interrupt_table(&os.idt);
}

pub fn setup_timer() void {

    io.outb(0x20, 0x11);
    io.outb(0xA0, 0x11);

    io.outb(0x21, 0x20);
    io.outb(0xA1, 0x28);

    io.outb(0x21, 0x04);
    io.outb(0xA1, 0x02);

    io.outb(0x21, 0x01);
    io.outb(0xA1, 0x01);

    io.outb(0x21, 0x0);
    io.outb(0xA1, 0x0);

    const divisor: u16 = 1193182 / 100;

    io.outb(0x43, 0x36);
    io.outb(0x40, @intCast(divisor & 0xFF));
    io.outb(0x40, @intCast((divisor >> 8) & 0xFF));
}
