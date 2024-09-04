const std = @import("std");
const BootInfo = @import("../structures/BootInfo.zig").BootInfo;
const Allocator = std.mem.Allocator;

const GDTEntry = @import("../structures/GDT.zig").GDTEntry;
const IDTEntry = @import("../structures/IDT.zig").IDTEntry;

pub var boot_info: BootInfo = undefined;
pub var allocator: Allocator = undefined;

pub var gdt: [3]GDTEntry = undefined;
pub var idt: [256]IDTEntry = undefined;
