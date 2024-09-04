const fmt = @import("std").fmt;
const port_io = @import("./port_io.zig");
pub const uart_port_com1 = 0x3f8;

pub fn uart_initialize() void {
    // The COM1 port + 1 is the Interrupt Enable register. If we set this to 1, the UART device would send us interrupts.
    // But we didn't set up interrupt handling right now (this is UP TO YOU!).
    // So we disable it.
    port_io.outb(uart_port_com1 + 1, 0x00);
    // Then, we set the DLAB bit in the Line Control Register. By doing this…
    port_io.outb(uart_port_com1 + 3, 0x80);
    // …we can send data to the COM1 port + 0 and that data does not write anything, but set the BAUD rate (at which frequency we want to communicate).
    // This is the least significant byte of that information…
    port_io.outb(uart_port_com1 + 0, 0x03);
    // …and here we have the most significant byte.
    port_io.outb(uart_port_com1 + 1, 0x00);
    // Now, we set different flags in the Line Control Register: We will set the default (8 bits, no parity, one stop bit).
    port_io.outb(uart_port_com1 + 3, 0x03);
    // Using this, we set some things in the FIFO (First In First Out) Control register:
    //   - the first bit enables FIFO buffers
    //   - the second bit clears the receive FIFO buffer
    //   - the third bit clears the transmit FIFO buffer
    //     - Those both bits will clear them by themselves after they cleared their FIFO buffer
    //   - the fourth bit is not used by me
    //   - the fifth and sixth bit is reserved
    //   - the seventh and eigth bit sets the interrupt trigger level (which specifies how much data must be received in the FIFO receive buffer before triggering a Received Data Available Interrupt).
    //     We want this to be the maximum as we don't want any interrupts, so the least possible computation is wasted.
    port_io.outb(uart_port_com1 + 2, 0xc7);
    // This sets some bits in the Modem Control Register.
    //   - the first bit controls the Data Terminal Ready pin
    //   - the second bit controls the Rquest to Send pin
    //   - the third bit us unused in PC implementations
    //   - the fourth bit controls a hardware pin which is used to enable the IRQ in PC implementations.
    //   - the fifth bit provides a local loopback feature for diagnostic testing of the UART
    //   - the sixth to eigth bytes are unused
    port_io.outb(uart_port_com1 + 4, 0x0b);
}

pub inline fn uart_is_transmit_buffer_empty() bool {
    // We ask the line statis register and if the sixth bit is set, the transmit buffer is full.
    return (port_io.inb(uart_port_com1 + 5) & 0x20) != 0;
}

pub inline fn uart_putchar(char: u8) void {
    while (!uart_is_transmit_buffer_empty()) {}
    port_io.outb(uart_port_com1, char);
}

pub fn uart_puts(str: []const u8) void {
    for (str) |char| {
        uart_putchar(char);
    }
}

pub inline fn uart_printf(comptime str: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined; 
    uart_puts(fmt.bufPrint(&buf, str, args) catch unreachable);
}