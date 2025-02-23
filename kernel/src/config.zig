pub const input = .{
    .usb = .{ .enable = false },
    .ps2 = .{ .enable = true, .keyboard = true, .mouse = true },
};

pub const max_ioapics = 5;

pub const debug_ignore: []const KeyValuePair = &[_]KeyValuePair{
    .{ .key = "Main", .value = default },
    .{ .key = "PMM", .value = ignore_all },
    .{ .key = "VMM", .value = ignore_all },
    .{ .key = "IDTM", .value = ignore_all },
    .{ .key = "Paging", .value = ignore_all },
    .{ .key = "Schedue", .value = ignore_all },
    .{ .key = "Stack Tracer", .value = ignore_all },

    .{ .key = "Drivers", .value = ignore_all },
    .{ .key = "ps2", .value = ignore_all },
    .{ .key = "PCI", .value = ignore_all },

    .{ .key = "Keyboard", .value = default },

    .{ .key = "Alloc", .value = ignore_all },

    .{ .key = "ProcessA", .value = default },
};

const KeyValuePair = struct { key: []const u8, value: u8 };
const default: u8 = 0b00000000;
const ignore_log: u8 = 0b00000001;
const ignore_err: u8 = 0b00000010;
const ignore_dbg: u8 = 0b00000100;
const ignore_warn: u8 = 0b00001000;
const ignore_all: u8 = 0b00001101;
