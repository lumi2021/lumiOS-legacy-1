//! This module provides simple text output for UEFI

// Again, our standard library
const std = @import("std");
const uefi = std.os.uefi;

// We want to have a global console output protocol.
var con_out: *uefi.protocol.SimpleTextOutput = undefined;
// But because that protocol is undefined at the beginning, we need to fill it (at runtime).
// This is why we need this variable.
var already_called_puts: bool = false;

/// This function puts out any normal string.
pub fn puts(msg: []const u8) void {
    // If this is the first time this function was called, we will do some setup.
    if (already_called_puts == false) {
        // We save the console output protocol from the system table (so we don't have to locate it).
        con_out = uefi.system_table.con_out.?;
        // We reset the screen…
        _ = con_out.reset(false);
        // And we set our variable to true, so we enter this condition only once.
        already_called_puts = true;
    }
    // Then, we iterate over the message we want to print out.
    for (msg) |c| {
        // For each character, we convert it to a null-terminated 16bit string.
        const c_ = [1:0]u16{c};
        // And then, we output that string.
        _ = con_out.outputString(&c_);
    }
}

/// This function puts out any formatted string, like std.debug.print does it.
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    // Because I don't want to allocate, I just have this buffer as a "limit".
    var buf: [256]u8 = undefined;
    // This is where I save the message.
    var msg: []u8 = undefined;
    // Now, we call a function from the standard library. It writes the string resulting from the format string and the arguments
    // into the buffer, but also returns a slice pointing to everything useful.
    msg = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;
    // And now, we just call our normal string output function.
    puts(msg);
}
