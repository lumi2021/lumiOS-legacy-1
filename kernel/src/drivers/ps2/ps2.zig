const os = @import("root").os;
const std = @import("std");

const ports = os.port_io;

const mouse = @import("mouse.zig");
const keyboard = @import("keyboard.zig");

const print = os.console_write("ps2");
const st = os.stack_tracer;

const max_readwrite_attempts = 10000;
const max_resend_attempts = 100;

pub fn init() void {
    st.push(@src()); defer st.pop();

    init_controllers() catch |err| {
        print.err("Unnable to initialize controlellers! ({s})", .{@errorName(err)});
        return;
    };

    print.log("PS/2 initialized", .{});
}

fn init_controllers() !void {

    // disabling devices and
    // cleaning the buffer
    disable_port_1();
    disable_port_2();
    flush();

    // Setting the command byte
    var config: CommandByte = @bitCast(try read_port(0x20));
    config.primary_irq_enabled = false;
    config.secondary_irq_enabled = false;
    config.scancode_translation_mode = true;
    try write_port(0x60, @bitCast(config));

    // Doing self-test 
    write_cmd(0xAA);
    if (try read_data() != 0x55) return error.selfTestFailed;

    // Setting com byte again bruh
    try write_port(0x60, @bitCast(config));

    // Checking dual-channel
   enable_port_2();
    config = @bitCast(try read_port(0x20));
    const dual_channel = config.secondary_clk_enable == .enabled;
    print.dbg("PS/2 controller has {s}", .{if (dual_channel) "two channels" else "one channel"});
    disable_port_2();

    print.dbg("Detecting enabled ports...", .{});

    var port_1 = true;
    var port_2 = dual_channel;

    var result: PortTestResult = undefined;
    // Performing interface tests
    
    if (port_1) {
        result = @enumFromInt(try read_port(0xAB));
        port_1 = result == .test_passed;
    }

    if (port_2) {
        result = @enumFromInt(try read_port(0xA9));
        port_2 = result == .test_passed;
    }

    if (!port_1 and !port_2) return error.all_ports_failed;

    // Enabling, reseting and detecting device in port 1
    if (port_1) {
        print.log("Device present in first port.", .{});
        enable_port_1();
        init_device(.primary) catch {
            disable_port_1();
            port_1 = false;
        };
    }
    if (port_2) {
        print.log("Device present in seccond port.", .{});
        enable_port_2();
        init_device(.secondary) catch {
            disable_port_2();
            port_2 = false;
        };
    }

    if (!port_1 and !port_2) return error.all_ports_failed;

    print.log("Enabling devices interrupt", .{});
    config = @bitCast(try read_port(0x20));
    config.primary_irq_enabled = port_1;
    config.secondary_irq_enabled = port_2;
    try write_port(0x60, @bitCast(config));
}


fn select_device(typeval: u8) !Device {
    if (typeval != 0xAB)  return switch (typeval) {
        0x00 => .Standard_Mouse,
        0x03 => .Scrollwheel_Mouse,
        0x04 => .Five_Button_Mouse,
        else => {
            print.err("Unknown device {X:2>0}", .{typeval});
            return .Unknown;
        },
    }
    else return switch (try read_data()) {
        0x41,
        0xC1 => .MF2_Keyboard_Translated,
        0x83 => .MF2_Keyboard,
        else => {
            print.err("Unknown device AB{X:2>0}", .{typeval});
            return .Unknown;
        }
    };
}
fn init_device(port: Port) !void {
    print.log("Reseting...", .{});

    try write_device(port, 0xFF);

    if (try read_data() != 0xAA) {
        print.err("Port 2 reset failed!", .{});
        return error.portResetFailed;
    }

    flush();
    try write_device(port, 0xF5); // Disable scanning
    try write_device(port, 0xF2); // Identifying devices
    const first = try read_data();

    const device = try select_device(first);
    print.log("Device in {s} port is {s} (irq {})", .{@tagName(port), @tagName(device), @as(u8, if (port == .primary) 1 else 12)});
    
    const port_irq: usize = switch (port) { .primary => 0x21, .secondary => 0x2C };

    switch (device) {
        .Standard_Mouse,
        .Scrollwheel_Mouse,
        .Five_Button_Mouse => mouse.init(port_irq),

        .MF2_Keyboard,
        .MF2_Keyboard_Translated => keyboard.init(port_irq),

        else => {}
    }

    try write_device(port, 0xF6);
    print.log("Enabling device scanning", .{});
    try write_device(port, 0xF4);
}


inline fn read_port(port: u8) !u8 {
    write_cmd(port);
    return try read_data();
}
inline fn write_port(port: u8, val: u8) !void {
    write_cmd(port);
    try write_data(val);
}

fn write_device(dev: Port, value: u8) !void {
    for (0 .. max_resend_attempts) |_| {

        if (dev == .secondary) write_cmd(0xD4);
        try write_data(value);

        await_ack() catch |err| switch (err) {
            error.resend => continue,
            else => return err
        };
        return;
    }

    return error.too_many_requests;
}

inline fn status() Status {
    return @bitCast(ports.inb(0x64));
}
inline fn write_cmd(value: u8) void {
    ports.outb(0x64, value);
}

fn write_data(value: u8) !void {
    for (0..max_readwrite_attempts) |_| if (canWrite()) return ports.outb(0x60, value);

    print.dbg("failed to write data", .{});
    return error.timeout;
}
fn read_data() !u8 {
    for (0..max_readwrite_attempts) |_| if (canRead()) return ports.inb(0x60);

    print.dbg("failed to read data", .{});
    return error.timeout;
}

inline fn flush() void {
    while (canRead()) _ = ports.inb(0x60);
}

inline fn canRead() bool {
    return status().output_buffer == .full;
}
inline fn canWrite() bool {
    return status().input_buffer == .empty;
}

fn await_ack() !void {
    switch (try read_data()) {
        0xFA => return,
        0xFE => return error.resend,
        else => |v| print.err("Got a different value: 0x{X}", .{v}),
    }
}

inline fn enable_port_1() void { write_cmd(0xAE); }
inline fn enable_port_2() void { write_cmd(0xA8); }
inline fn disable_port_1() void { write_cmd(0xAD); }
inline fn disable_port_2() void { write_cmd(0xA7); }

const Status = packed struct(u8) {
    output_buffer: BufferState, // if full, data can be read from `data` port
    input_buffer: BufferState, // if empty, data can be written to `data` port
    selftest_ok: bool, // state of the self test. should always be `true`.
    last_port: u1, // last used port. 0=>0x60, 1=>0x61 or 0x64.
    keyboard_lock: KeyboardLockState,
    aux_input_buffer: BufferState, // PSAUX?
    timeout: bool, // If `true`, the device doesn't respond.
    parity_error: bool, // If `true`, a transmit error happend for the last read or write.
};
const KeyboardLockState = enum(u1) {
    locked = 0,
    unlocked = 1,
};
const BufferState = enum(u1) {
    empty = 0,
    full = 1,
};

const CommandByte = packed struct(u8) {
    const ClockEnable = enum(u1) {
        enabled = 0,
        disabled = 1,
    };

    primary_irq_enabled: bool, // 0: First PS/2 port interrupt (1 = enabled, 0 = disabled)
    secondary_irq_enabled: bool, // 1: Second PS/2 port interrupt (1 = enabled, 0 = disabled, only if 2 PS/2 ports supported)
    system_flag: bool, // 2: System Flag (1 = system passed POST, 0 = your OS shouldn't be running)
    ignore_safety_state: bool, // 3: Should be zero
    primary_clk_enable: ClockEnable, // 4: First PS/2 port clock (1 = disabled, 0 = enabled)
    secondary_clk_enable: ClockEnable, // 5: Second PS/2 port clock (1 = disabled, 0 = enabled, only if 2 PS/2 ports supported)
    scancode_translation_mode: bool, // 6: First PS/2 port translation (1 = enabled, 0 = disabled)
    reserved: u1, // 7: must be zero
};

const PortTestResult = enum(u8) {
    test_passed = 0x00,
    clock_line_stuck_low = 0x01,
    clock_line_stuck_high = 0x02,
    data_line_stuck_low = 0x03,
    data_line_stuck_high = 0x04,
    _,
};

const Port = enum {
    primary,
    secondary
};
const Device = enum {
    Unknown, 

    Standard_Mouse,
    Scrollwheel_Mouse,
    Five_Button_Mouse,

    MF2_Keyboard,
    MF2_Keyboard_Translated,

};
