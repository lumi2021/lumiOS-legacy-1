const std = @import("std");
const os = @import("root").os;
const uart = @import("uart.zig");
const bcom = os.GL.bcom;

const puts = uart.uart_puts;
const printf = uart.uart_printf;

pub fn write(comptime tag: []const u8) type {
    return struct {
        pub const log = struct {
            pub fn f(comptime fmt: []const u8, args: anytype) void {
                if (isLogDisabled(tag)) return;
                printf("[" ++ tag ++ " log] " ++ fmt ++ "\r\n", args);
                //bcom.printfc("[" ++ tag ++ " log] " ++ fmt ++ "\r\n", args, 0xF8F8F2);
            }
        }.f;

        pub const warn = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                if (isWarnDisabled(tag)) return;
                printf("[" ++ tag ++ " warn] " ++ fmt ++ "\r\n", args);
                //bcom.printfc("[" ++ tag ++ " warn] " ++ fmt ++ "\r\n", args, 0xFFFF00);
            }
        }.f;

        pub const dbg = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                if (isDbgDisabled(tag)) return;
                printf("[" ++ tag ++ " dbg] " ++ fmt ++ "\r\n", args);
                //bcom.printfc("[" ++ tag ++ " dbg] " ++ fmt ++ "\r\n", args, 0x777777);
            }
        }.f;

        pub const err = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                if (isErrDisabled(tag)) return;
                printf("[" ++ tag ++ " error] " ++ fmt ++ "\r\n", args);
                //bcom.printfc("[" ++ tag ++ " error] " ++ fmt ++ "\r\n", args, 0xFF0000);
            }
        }.f;

        pub const raw = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                if (isLogDisabled(tag)) return;
                printf(fmt, args);
                //bcom.printf(fmt, args);
            }
        }.f;
    };
}

fn isLogDisabled(comptime tag: []const u8) bool {
    for (os.config.debug_ignore) |i| {
        if (std.mem.eql(u8, tag, i.key) and (i.value & 0b0001) != 0) return true;
    }
    return false;
}
fn isErrDisabled(comptime tag: []const u8) bool {
    for (os.config.debug_ignore) |i| {
        if (std.mem.eql(u8, tag, i.key) and (i.value & 0b0010) != 0) return true;
    }
    return false;
}
fn isDbgDisabled(comptime tag: []const u8) bool {
    for (os.config.debug_ignore) |i| {
        if (std.mem.eql(u8, tag, i.key) and (i.value & 0b0100) != 0) return true;
    }
    return false;
}
fn isWarnDisabled(comptime tag: []const u8) bool {
    for (os.config.debug_ignore) |i| {
        if (std.mem.eql(u8, tag, i.key) and (i.value & 0b1000) != 0) return true;
    }
    return false;
}
