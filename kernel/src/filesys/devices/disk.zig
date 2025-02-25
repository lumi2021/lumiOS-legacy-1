const os = @import("root").os;

const ports = os.port_io;
const primary_io = 0x1F0;

const write = os.console_write("Disk");
const st = os.stack_tracer;

pub inline fn read_sector(sector: u32, buffer: *[512]u8) void {
    return ata_read_sector(sector, buffer);
}

fn ata_read_sector(lba: u32, buffer: *[512]u8) void {
    st.push(@src()); defer st.pop();

    // Test 32-bits
    const test_value: u8 = 0xAA;
    ports.outb(primary_io + 1, test_value);
    const read_value = ports.inb(primary_io + 1);

    if (read_value == test_value) {
        write.log("Disco suporta acesso de 32 bits", .{});
    } else {
        write.log("Disco suporta apenas acesso de 16 bits", .{});
    }


    // Wait if not ready
    ata_await();

    // Select driver (master) and LBA high bits
    ports.outb(primary_io + 6, @intCast(0xE0 | ((lba >> 24) & 0x0F)));

    // Sectors to read (1 sector)
    ports.outb(primary_io + 2, 1);

    // load LBA
    ports.outb(primary_io + 3, @intCast(lba));
    ports.outb(primary_io + 4, @intCast(lba >> 8));
    ports.outb(primary_io + 5, @intCast(lba >> 16));

    // Request read
    ports.outb(primary_io + 7, 0x20);

    // Wait disk
    ata_await();

    // Read sector
    write.dbg("Buffer: ", .{});

    for (0..256) |i| {
        const word = ports.inw(primary_io);
        write.raw("{X:0>4}", .{word});
        buffer[i*2]   = @intCast(word & 0xFF);
        buffer[i*2+1] = @intCast((word >> 8) & 0xFF);
    }
    write.raw("\n", .{});

    write.log("sector {} readed", .{lba});
}

inline fn ata_await() void {
    st.push(@src()); defer st.pop();
    while ((status() & 0x88) == 0x00) {}
}

inline fn status() u8 {
    return ports.inb(primary_io + 7);
}
