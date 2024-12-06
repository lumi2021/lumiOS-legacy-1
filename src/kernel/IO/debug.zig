const uart = @import("uart.zig");

const puts = uart.uart_puts;
const printf = uart.uart_printf;

pub fn write(comptime tag: []const u8) type {
    return struct {
        pub const log = struct {
            pub fn f(comptime fmt: []const u8, args: anytype) void {
                printf("[" ++ tag ++ " log] " ++ fmt ++ "\r\n", args);
            }
        }.f;

        pub const warn = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                printf("[" ++ tag ++ " warn] " ++ fmt ++ "\r\n", args);
            }
        }.f;

        pub const dbg = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                printf("[" ++ tag ++ " info] " ++ fmt ++ "\r\n", args);
            }
        }.f;

        pub const err = struct {
            pub inline fn f(comptime fmt: []const u8, args: anytype) void {
                printf("[" ++ tag ++ " error] " ++ fmt ++ "\r\n", args);
            }
        }.f;
    };
}
