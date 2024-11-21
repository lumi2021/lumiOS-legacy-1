const std = @import("std");
const io = @import("IO/port_io.zig");
const os = @import("OS/os.zig");
const cpuid = @import("utils/cpuid.zig");

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

const pci = @import("drivers/pci/pci.zig");

const write = @import("IO/debug.zig").write("Setup");

pub fn init_setup() void {
    
    write.dbg("setupping GDT...", .{});
    setup_GDT();

    write.dbg("setupping IDT...", .{});
    setup_IDT();

    const paging_feats = paging.enumerate_paging_features();
    
    pmm.init(paging_feats.maxphyaddr, os.boot_info.memory_map);
    write.dbg("initialized lower phys mem", .{});

    vmm.init(os.boot_info.memory_map) catch @panic("Error during VMM init!");

    write.dbg("setupping Allocator...", .{});
    setup_Allocator();

    write.dbg("setupping Task Manager...", .{});
    setup_Task_manager();

    write.dbg("starting Schedue...", .{});
    setup_timer();

    write.dbg("starting PCI", .{});
    pci.init() catch @panic("PCI cannot be initialized!");

}


pub inline fn setup_Allocator() void {
    os.allocator = vmm.raw_page_allocator.allocator();
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
