const uart = @import("uart.zig");

pub const puts = uart.uart_puts;
pub const printf = uart.uart_printf;