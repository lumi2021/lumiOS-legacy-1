const std = @import("std");
const os = @import("root").os;
const fmt = std.fmt;
const uart = os.uart;

const puts = uart.uart_puts;
const printf = uart.uart_printf;

const StringList = std.ArrayList([256]u8);
pub var history: StringList = undefined;
pub var history_enabled: bool = false;

var buf: [1024]u8 = undefined;

pub fn write(comptime tag: []const u8) type {
    return struct {
        pub const log = struct {
            pub fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Log)) return;
                
                const str = fmt.bufPrint(&buf, "[" ++ tag ++ " log] " ++ base ++ "\r\n", args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const warn = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Warn)) return;

                const str = fmt.bufPrint(&buf, "[" ++ tag ++ " warn] " ++ base ++ "\r\n", args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const dbg = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Debug)) return;
                
                const str = fmt.bufPrint(&buf, "[" ++ tag ++ " dbg] " ++ base ++ "\r\n", args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const err = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {
                if (isDisabled(tag, .Error)) return;
                
                const str = fmt.bufPrint(&buf, "[" ++ tag ++ " error] " ++ base ++ "\r\n", args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;

        pub const raw = struct {
            pub inline fn f(comptime base: []const u8, args: anytype) void {

                const str = fmt.bufPrint(&buf, base, args) catch unreachable;
                puts(str);
                add_to_history(str);
            }
        }.f;
    
        pub const isModeEnabled = struct {
            pub inline fn f(mode: Mode) bool {
                return !isDisabled(tag, mode);
            }
        }.f;
    };
}

fn isDisabled(comptime tag: []const u8, comptime mode: Mode) bool {
    for (os.config.debug_ignore) |i|
        if (std.mem.eql(u8, tag, i.key) and (i.value & @intFromEnum(mode)) != 0) return true;
    return false;
}
const Mode = enum(u8) {
    Log =   0b0001,
    Error = 0b0010,
    Debug = 0b0100,
    Warn =  0b1000
};


pub fn create_history() !void {
    history = StringList.init(os.memory.allocator);
    history_enabled = true;
}
pub fn add_to_history(str: []const u8) void {
    if (!history_enabled) return;

    var lines = std.mem.splitAny(u8, str, "\n");
    var line = lines.next();

    while (line != null) : (line = lines.next()) {
        const item = history.addOne() catch unreachable;
        @memset(item, 0);
        _ = fmt.bufPrint(item, "{s}", .{line.?}) catch unreachable;
    }

    if (std.mem.sliceTo(&history.items[history.items.len - 1], '0').len == 0) {
        _ = history.orderedRemove(history.items.len - 1);
    }
}
