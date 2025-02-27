pub const BootInfo = struct {
    kernel_physical_base: u64,
    kernel_virtual_base: u64,

    hhdm_address_offset: u64,

    memory_map: []*MemoryMapEntry,
    framebuffer: FrameBuffer,
};

pub const MemoryMapEntry = extern struct {
    base: u64,
    size: u64,
    type: RegionType,
};

pub const RegionType = enum(u64) {
    usable = 0,
    reserved = 1,
    acpi_reclaimable = 2,
    acpi_nvs = 3,
    bad_memory = 4,
    bootloader_reclaimable = 5,
    kernel_and_modules = 6,
    framebuffer = 7,
};

pub const FrameBuffer = extern struct {
    framebuffer: [*]u8,
    size: usize,
    width: u64,
    height: u64,
    pixels_per_scan_line: u64,
};
