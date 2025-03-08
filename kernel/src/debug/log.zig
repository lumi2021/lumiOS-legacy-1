const std = @import("std");
const os = @import("root").os;
const uart = os.uart;
const bcom = os.GL.bcom;

const puts = uart.uart_puts;
const printf = uart.uart_printf;

pub fn write(comptime tag: []const u8) type {
    return struct {
        pub const log = struct {
            pub fn f(comptime fmt: []const u8, args: anytype) void {
                if (isDisabled(tag, .Log)) return;
                printf("[" ++ tag ++ " log] " ++ fmt ++ "\r\n", args);
                bcom.printfc("[" ++ tag ++ "] " ++ fmt ++ "\n", args, 0xF8F8F2);
            }
        }.f;

        pub const warn = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                if (isDisabled(tag, .Warn)) return;
                printf("[" ++ tag ++ " warn] " ++ fmt ++ "\r\n", args);
                bcom.printfc("[" ++ tag ++ "] " ++ fmt ++ "\n", args, 0xFFFF00);
            }
        }.f;

        pub const dbg = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                if (isDisabled(tag, .Debug)) return;
                printf("[" ++ tag ++ " dbg] " ++ fmt ++ "\r\n", args);
                bcom.printfc("[" ++ tag ++ "] " ++ fmt ++ "\n", args, 0x777777);
            }
        }.f;

        pub const err = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                if (isDisabled(tag, .Error)) return;
                printf("[" ++ tag ++ " error] " ++ fmt ++ "\r\n", args);
                bcom.printfc("[" ++ tag ++ "] " ++ fmt ++ "\n", args, 0xFF0000);
            }
        }.f;

        pub const raw = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                printf(fmt, args);
                bcom.printf(fmt, args);
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
