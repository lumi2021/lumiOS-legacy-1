const os = @import("root").os;
const std = @import("std");

const ports = os.port_io;

const mouse = @import("mouse.zig");
const keyboard = @import("keyboard.zig");

const log = os.console_write("ps2");
const st = os.stack_tracer;

const max_readwrite_attempts = 10000;
const max_resend_attempts = 100;

const Device = enum {
    primary,
    secondary,
};

pub fn init() void {
    st.push(@src());
    defer st.pop();

    init_controllers() catch |err| {
        log.err("Unnable to initialize controlellers! {s}", .{@errorName(err)});
        return;
    };

    log.log("ps2 initialized", .{});
}

pub fn init_controllers() !void {
    st.push(@src());
    defer st.pop();

    try disablePrimaryPort();
    try disableSecondaryPort();

    _ = ports.inb(0x60);

    // Disable interrupts, enable translation
    const init_config_byte = (1 << 6) | (~@as(u8, 3) & try getConfigByte());
    try writeConfigByte(init_config_byte);

    if (!try controllerSelfTest()) {
        log.warn("Controller self-test failed!", .{});
        return error.FailedSelfTest;
    }

    log.dbg("Controller self-test succeeded", .{});

    try writeConfigByte(init_config_byte);

    var dual_channel = ((1 << 5) & init_config_byte) != 0;

    if (dual_channel) {
        try enableSecondaryPort();
        dual_channel = ((1 << 5) & try getConfigByte()) == 0;
        try disableSecondaryPort();
    } else log.dbg("Not dual channel", .{});

    log.log("Detecting active ports, dual_channel = {}", .{dual_channel});

    try enablePrimaryPort();

    if (testPrimaryPort() catch false) {
        log.dbg("Initializing primary port", .{});
        try enablePrimaryPort();

        if (!(initDevice(1, .primary) catch false)) {
            try disablePrimaryPort();
            log.warn("Primary device init failed, disabled port", .{});
        }
    }

    if (dual_channel and testSecondaryPort() catch false) {
        log.dbg("Initializing secondary port", .{});
        try enableSecondaryPort();

        if (!(initDevice(12, .secondary) catch false)) {
            try disableSecondaryPort();
            log.warn("Secondary device init failed, disabled port", .{});
        }
    }
}

fn initDevice(irq: u8, device: Device) !bool {
    st.push(@src());
    defer st.pop();

    log.log("Trying to init device {s} in irq {}", .{ @tagName(device), irq });

    log.dbg(" - Resetting device", .{});

    try sendCommand(device, 0xFF);

    if (0xAA != try read()) {
        log.err("- Device reset failed", .{});
        return error.DeviceResetFailed;
    }

    try sendCommand(device, 0xF5); // Disabling scanning
    try sendCommand(device, 0xF2); // Identifying device

    const first = read() catch |err| {
        switch (err) {
            error.Timeout => {
                log.warn(" - No identity byte, assuming keyboard", .{});
                return initKeyboard(irq, device);
            },
            else => return err,
        }
    };

    switch (first) {
        0x00 => {
            log.dbg(" - PS2: Standard mouse", .{});
            return initMouse(irq, device);
        },
        0x03 => {
            log.dbg(" - Scrollwheel mouse", .{});
            return initMouse(irq, device);
        },
        0x04 => {
            log.dbg(" - 5-button mouse", .{});
            return initMouse(irq, device);
        },
        0xAB => {
            switch (try read()) {
                0x41, 0xC1 => {
                    log.dbg(" - MF2 keyboard with translation", .{});
                    return initKeyboard(irq, device);
                },
                0x83 => {
                    log.dbg(" - MF2 keyboard", .{});
                    return initKeyboard(irq, device);
                },
                else => |wtf| {
                    log.warn(" - Identify: Unknown byte after 0xAB: 0x{X}", .{wtf});
                },
            }
        },
        else => {
            log.warn(" - Identify: Unknown first byte: 0x{X}", .{first});
        },
    }

    return false;
}
fn enableDevice(device: Device) !void {
    st.push(@src());
    defer st.pop();

    log.dbg(" --- Enabling interrupts", .{});

    var shift: u1 = 0;
    if (device == .secondary) shift = 1;
    try writeConfigByte((@as(u2, 1) << shift) | try getConfigByte());

    log.dbg(" --- Enabling scanning", .{});
    try sendCommand(device, 0xF4);
}

// init specific devices
fn initMouse(irq: u8, device: Device) !bool {
    if (!os.config.input.ps2.mouse) return false;

    st.push(@src());
    defer st.pop();

    log.log(" -- Initializing mouse ({s} in irq {})", .{ @tagName(device), irq });

    mouse.init();

    try enableDevice(device);

    return true;
}
fn initKeyboard(irq: u8, device: Device) !bool {
    if (!os.config.input.ps2.keyboard) return false;

    st.push(@src());
    defer st.pop();

    log.log(" -- Initializing keyboard ({s} in irq {})", .{ @tagName(device), irq });

    keyboard.init();

    try enableDevice(device);

    return true;
}

// can read/write
fn canWrite() bool {
    return (ports.inb(0x64) & 2) == 0;
}
fn canRead() bool {
    return (ports.inb(0x64) & 1) != 0;
}

// read/write
fn write(port: u16, value: u8) !void {
    var counter: usize = 0;
    while (counter < max_readwrite_attempts) : (counter += 1) {
        if (canWrite()) {
            return ports.outb(port, value);
        }
    }

    log.warn("Timeout while writing to port 0x{X}!", .{port});
    return error.Timeout;
}
fn read() !u8 {
    var counter: usize = 0;
    while (counter < max_readwrite_attempts) : (counter += 1) {
        if (canRead()) {
            return ports.inb(0x60);
        }
    }

    log.warn("Timeout while reading!", .{});
    return error.Timeout;
}

// Config bytes
fn getConfigByte() !u8 {
    try write(0x64, 0x20);
    return read();
}
fn writeConfigByte(config_byte_value: u8) !void {
    try write(0x64, 0x60);
    try write(0x60, config_byte_value);
}

// Test controller
fn controllerSelfTest() !bool {
    try write(0x64, 0xAA);
    return 0x55 == try read();
}

// Test ports
fn testPrimaryPort() !bool {
    try write(0x64, 0xAB);
    return portTest();
}
fn testSecondaryPort() !bool {
    try write(0x64, 0xA9);
    return portTest();
}
fn portTest() !bool {
    switch (try read()) {
        0x00 => return true, // Success
        0x01 => log.err("Port test failed: Clock line stuck low", .{}),
        0x02 => log.err("Port test failed: Clock line stuck high", .{}),
        0x03 => log.err("Port test failed: Data line stuck low", .{}),
        0x04 => log.err("Port test failed: Data line stuck high", .{}),
        else => |result| log.err("Port test failed: Unknown reason (0x{X})", .{result}),
    }
    return false;
}

// Enable/Disable ports
fn disablePrimaryPort() !void {
    try write(0x64, 0xAD);
}
fn enablePrimaryPort() !void {
    try write(0x64, 0xAE);
}
fn enableSecondaryPort() !void {
    try write(0x64, 0xA8);
}
fn disableSecondaryPort() !void {
    try write(0x64, 0xA7);
}

// Device things
fn sendCommand(device: Device, command: u8) !void {
    var resends: usize = 0;
    while (resends < max_resend_attempts) : (resends += 1) {
        if (device == .secondary) {
            try write(0x64, 0xD4);
        }
        try write(0x60, command);
        awaitAck() catch |err| {
            switch (err) {
                error.Resend => {
                    log.dbg("Device requested command resend", .{});
                    continue;
                },
                else => return err,
            }
        };
        return;
    }

    return error.TooManyResends;
}
fn awaitAck() !void {
    while (true) {
        const v = read() catch |err| {
            log.err("ACK read failed: {s}!", .{@errorName(err)});
            return err;
        };

        switch (v) {
            // ACK
            0xFA => return,

            // Resend
            0xFE => return error.Resend,

            else => log.err("Got a different value: 0x{X}", .{v}),
        }
    }
}
