pub const input = .{
    .usb = .{ .enable = false },
    .ps2 = .{ .enable = true, .keyboard = true, .mouse = true },
};

pub const max_ioapics = 5;

pub const debug_ignore: []const KeyValuePair = &[_]KeyValuePair{
    // main setup
    .{ .key = "Main", .value = ignore_all },
    
    // memory
    .{ .key = "PMM", .value = ignore_all },
    .{ .key = "VMM", .value = ignore_all },
    .{ .key = "Paging", .value = ignore_all },

    // threading
    .{ .key = "schedue", .value = ignore_all },
    .{ .key = "taskman", .value = ignore_all },
    .{ .key = "task", .value = ignore_all },

    // interruptions
    .{ .key = "IDTM", .value = ignore_all },
    .{ .key = "syscall", .value = ignore_all },

    // file system
    .{ .key = "fs", .value = ignore_all },

    // Drivers related
    .{ .key = "Drivers", .value = ignore_all },
    .{ .key = "PCI", .value = default },
    .{ .key = "xHCI", .value = ignore_all },
    .{ .key = "ps2", .value = ignore_all },
    .{ .key = "keyboard", .value = ignore_all },
    .{ .key = "mouse", .value = ignore_all },

    // Allocations
    .{ .key = "Alloc", .value = ignore_all },

    .{ .key = "ProcessA", .value = default },

    // Debug
    .{ .key = "Stack Tracer", .value = ignore_all },
};

const KeyValuePair = struct { key: []const u8, value: u8 };
const default: u8 = 0b00000000;
const ignore_log: u8 = 0b00000001;
const ignore_err: u8 = 0b00000010;
const ignore_dbg: u8 = 0b00000100;
const ignore_warn: u8 = 0b00001000;
const ignore_all: u8 = 0b00001101;
