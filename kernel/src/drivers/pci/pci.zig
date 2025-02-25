const std = @import("std");
const os = @import("root").os;
const port = os.port_io;

const xhci = @import("../usb/xhci.zig");

const write = os.console_write("PCI");
const st = os.stack_tracer;

pub const regoff = u8;

pub const Addr = struct {
    bus: u8,
    device: u5,
    function: u3,

    pub const vendor_id = cfgreg(u16, 0x00);
    pub const device_id = cfgreg(u16, 0x02);
    pub const command = cfgreg(u16, 0x04);
    pub const status = cfgreg(u16, 0x06);
    pub const prog_if = cfgreg(u8, 0x09);
    pub const header_type = cfgreg(u8, 0x0E);
    pub const base_class = cfgreg(u8, 0x0B);
    pub const sub_class = cfgreg(u8, 0x0A);
    pub const secondary_bus = cfgreg(u8, 0x19);
    pub const cap_ptr = cfgreg(u8, 0x34);
    pub const int_line = cfgreg(u8, 0x3C);
    pub const int_pin = cfgreg(u8, 0x3D);

    pub fn barinfo(self: Addr, bar_idx: u8) BarInfo {
        var orig: u64 = self.read(u32, 0x10 + bar_idx * 4) & 0xFFFFFFF0;
        self.write(u32, 0x10 + bar_idx * 4, 0xFFFFFFFF);
        const pci_out = self.read(u32, 0x10 + bar_idx * 4);
        const is64 = ((pci_out & 0b110) >> 1) == 2; // bits 1:2, bar type (0 = 32bit, 1 = 64bit)

        self.write(u32, 0x10 + bar_idx * 4, @truncate(orig));

        var response: u64 = @as(u64, pci_out & 0xFFFFFFF0);
        if (is64) {
            orig |= @as(u64, self.read(u32, 0x14 + bar_idx * 4)) << 32;
            self.write(u32, 0x14 + bar_idx * 4, 0xFFFFFFFF); // 64bit bar = two 32-bit bars
            response |= @as(u64, self.read(u32, 0x14 + bar_idx * 4)) << 32;
            self.write(u32, 0x14 + bar_idx * 4, @truncate(orig >> 32));
            return .{ .phy = orig, .size = ~response +% 1 };
        } else {
            return .{ .phy = orig, .size = (~response +% 1) & 0xFFFFFFFF };
        }
    }

    pub fn read(self: Addr, comptime T: type, offset: regoff) T {
        pci_space_request(self, offset);
        return port.in(T, 0xCFC + @as(u16, offset % 4));
    }

    pub fn write(self: Addr, comptime T: type, offset: regoff, value: T) void {
        pci_space_request(self, offset);
        return port.out(T, 0xCFC + @as(u16, offset % 4), value);
    }
};

const BarInfo = struct {
    phy: u64,
    size: u64,
};

pub fn init() !void {
    st.push(@src());

    write.log("Scanning bus root...", .{});
    bus_scan(0);
    write.log("Scan complete!", .{});

    st.pop();
}

fn bus_scan(bus: u8) void {
    st.push(@src());

    inline for (0..(1 << 5)) |device| {
        device_scan(bus, @intCast(device));
    }

    st.pop();
}

pub fn device_scan(bus: u8, device: u5) void {
    st.push(@src());

    const nullfunc: Addr = .{ .bus = bus, .device = device, .function = 0 };

    if (nullfunc.header_type().read() == 0xFFFF) {
        st.pop();
        return;
    }

    function_scan(nullfunc);

    if (nullfunc.header_type().read() & 0x80 == 0) {
        st.pop();
        return;
    }

    inline for (0..((1 << 3) - 1)) |function| {
        function_scan(.{ .bus = bus, .device = device, .function = @intCast(function + 1) });
    }

    st.pop();
}

pub fn function_scan(addr: Addr) void {
    st.push(@src());

    if (addr.vendor_id().read() == 0xFFFF) {
        st.pop();
        return;
    }

    switch (addr.base_class().read()) {
        else => {
            write.log(" - Unknown class!", .{});
        },
        0x00 => {
            switch (addr.sub_class().read()) {
                else => {
                    write.log(" - Unknown unclassified device!", .{});
                },
            }
        },
        0x01 => {
            switch (addr.sub_class().read()) {
                else => {
                    write.log(" - Unknown storage controller!", .{});
                },
                0x06 => {
                    write.log(" - AHCI controller", .{});
                    os.drivers.disk.register_SATA_drive(addr);
                },
                0x08 => {
                    switch (addr.prog_if().read()) {
                        else => {
                            write.log(" - Unknown non-volatile memory controller!", .{});
                        },
                        0x02 => {
                            write.log(" - NVMe controller", .{});
                        },
                    }
                },
            }
        },
        0x02 => {
            switch (addr.sub_class().read()) {
                else => {
                    write.log(" - Unknown network controller!", .{});
                },
                0x00 => {
                    if (addr.vendor_id().read() == 0x8086 and addr.device_id().read() == 0x100E) {
                        write.log(" - E1000 controller", .{});
                    } else {
                        write.log(" - Unknown ethernet controller", .{});
                    }
                },
                0x80 => {
                    write.log(" - Other network controller", .{});
                },
            }
        },
        0x03 => {
            if (addr.vendor_id().read() == 0x1AF4 and addr.device_id().read() == 0x1050) {
                write.log("Virtio display controller", .{});
            } else switch (addr.sub_class().read()) {
                else => {
                    write.log(" - Unknown display controller!", .{});
                },
                0x00 => {
                    write.log(" - VGA compatible controller", .{});
                },
            }
        },
        0x04 => {
            switch (addr.sub_class().read()) {
                else => {
                    write.log(" - Unknown multimedia controller!", .{});
                },
                0x03 => {
                    write.log(" - Audio device", .{});
                },
            }
        },
        0x06 => {
            switch (addr.sub_class().read()) {
                else => {
                    write.log(" - Unknown bridge device!", .{});
                },
                0x00 => {
                    write.log(" - Host bridge", .{});
                },
                0x01 => {
                    write.log(" - ISA bridge", .{});
                },
                0x04 => {
                    write.log(" - PCI-to-PCI bridge", .{});
                    if ((addr.header_type().read() & 0x7F) != 0x01) {
                        write.log("Not PCI-to-PCI bridge header type!", .{});
                    } else {
                        const secondary_bus = addr.secondary_bus().read();
                        write.log(", recursively scanning bus {0X}", .{secondary_bus});
                        bus_scan(secondary_bus);
                    }
                },
            }
        },
        0x0c => {
            switch (addr.sub_class().read()) {
                else => {
                    write.log(" - Unknown serial bus controller!", .{});
                },
                0x03 => {
                    switch (addr.prog_if().read()) {
                        else => {
                            write.log(" - Unknown USB controller!", .{});
                        },
                        0x20 => {
                            write.log(" - USB2 EHCI controller", .{});
                        },
                        0x30 => {
                            write.log(" - USB3 XHCI controller", .{});
                            xhci.register_device(addr);
                        },
                    }
                },
            }
        },
    }

    st.pop();
}

fn cfgreg(comptime T: type, comptime off: regoff) fn (self: Addr) PciFn(T, off) {
    return struct {
        fn function(self: Addr) PciFn(T, off) {
            return .{ .self = self };
        }
    }.function;
}

fn PciFn(comptime T: type, comptime off: regoff) type {
    return struct {
        self: Addr,
        pub fn read(self: @This()) T {
            return self.self.read(T, off);
        }
        pub fn write(self: @This(), val: T) void {
            self.self.write(T, off, val);
        }
    };
}

fn pci_space_request(addr: Addr, offset: regoff) void {
    const val = 1 << 31 | @as(u32, offset) | @as(u32, addr.function) << 8 | @as(u32, addr.device) << 11 | @as(u32, addr.bus) << 16;
    port.outl(0xCF8, val);
}
