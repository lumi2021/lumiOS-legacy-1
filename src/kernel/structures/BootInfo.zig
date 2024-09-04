const dbg = @import("../IO/debug.zig");

pub const BootInfo = extern struct {

    memory_map : *[]MemoryMapEntry,
    framebuffer : FrameBuffer,
};
pub const MemoryMapEntry = extern struct {

    base: u64,
    size: u64,

    type: RegionType,
    attributes: ExtendedAddressRangeAttributes,

    pub fn printFormated(self: *const @This()) void {
        dbg.puts("MemoryMapEntry {\r\n");
        dbg.printf("\tbase: 0x{X:0>16}; ", .{self.base_address});
        dbg.printf("size: 0x{X}; ", .{self.size});
        dbg.printf("type: {s}; ", .{@tagName(self.type)});

        dbg.puts("\r\n\tattributes: [");

        if (self.attributes.uncacheable) dbg.puts("uncacheable, ");
        if (self.attributes.write_combining) dbg.puts("write_combining, ");
        if (self.attributes.write_through) dbg.puts("write_through, ");
        if (self.attributes.write_back) dbg.puts("write_back, ");
        if (self.attributes.uncacheable_exported) dbg.puts("uncacheable_exported, ");
        if (self.attributes.write_protected) dbg.puts("write_protected, ");
        if (self.attributes.read_protected) dbg.puts("read_protected, ");
        if (self.attributes.execute_protected) dbg.puts("execute_protected, ");
        if (self.attributes.more_reliable) dbg.puts("more_reliable, ");
        if (self.attributes.read_only) dbg.puts("read_only, ");
        if (self.attributes.self_protected) dbg.puts("self_protected, ");
        if (self.attributes.cpu_crypto) dbg.puts("cpu_crypto, ");
        if (self.attributes.memory_runtime) dbg.puts("memory_runtime, ");

        dbg.puts("]");
        dbg.puts("\r\n}\n\r");
    }

};
pub const FrameBuffer = extern struct {

    base_address: u64,
    size: usize,
    width: u32,
    height: u32,
    pixels_per_scan_line: u32

};


pub const RegionType = enum(u32) {
    /// Not usable.
    reserved,

    /// The code portions of a loaded application.
    loader_code,

    /// The data portions of a loaded application and the default data allocation type used by an application to
    /// allocate pool memory.
    loader_data,

    /// The code portions of a loaded Boot Services Driver.
    boot_services_code,

    /// The data portions of a loaded Boot Services Driver, and the default data allocation type used by a Boot
    /// Services Driver to allocate pool memory.
    boot_services_data,

    /// The code portions of a loaded Runtime Services Driver.
    runtime_services_code,

    /// The data portions of a loaded Runtime Services Driver and the default data allocation type used by a Runtime
    /// Services Driver to allocate pool memory.
    runtime_services_data,

    /// Free (unallocated) memory.
    conventional,

    /// Memory in which errors have been detected.
    unusable,

    /// Memory that holds the ACPI tables.
    acpi_reclaim,

    /// Address space reserved for use by the firmware.
    acpi_nvs,

    /// Used by system firmware to request that a memory-mapped IO region be mapped by the OS to a virtual address so
    /// it can be accessed by EFI runtime services.
    memory_mapped_io,

    /// System memory-mapped IO region that is used to translate memory cycles to IO cycles by the processor.
    memory_mapped_io_port_space,

    /// Address space reserved by the firmware for code that is part of the processor.
    pal_code,

    /// A memory region that operates as `conventional`, but additionally supports byte-addressable non-volatility.
    persistent,

    /// A memory region that represents unaccepted memory that must be accepted by the boot target before it can be used.
    /// For platforms that support unaccepted memory, all unaccepted valid memory will be reported in the memory map.
    /// Unreported memory addresses must be treated as non-present memory.
    unaccepted,

    _,
};

pub const ExtendedAddressRangeAttributes = packed struct(u64) {
    uncacheable: bool,
    write_combining: bool,
    write_through: bool,
    write_back: bool,
    uncacheable_exported: bool,
    _pad1: u7 = 0,
    write_protected: bool,
    read_protected: bool,
    execute_protected: bool,
    non_volatile: bool,
    more_reliable: bool,
    read_only: bool,
    self_protected: bool,
    cpu_crypto: bool,
    _pad2: u43 = 0,
    memory_runtime: bool,
};
