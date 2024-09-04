const std = @import("std");
const uefi = std.os.uefi;
const structures = @import("structures.zig");

const text_out = @import("./text_out.zig");
const config = @import("./config.zig");
const loader = @import("./loader.zig");
const efi_aditional = @import("./efi_additional.zig");
const puts = text_out.puts;
const printf = text_out.printf;

pub const BootInfo = structures.BootInfo;
pub const MemoryMapEntry = structures.MemoryMapEntry;
pub const FrameBuffer = structures.FrameBuffer;


fn bootloader() uefi.Status {
    const boot_services = uefi.system_table.boot_services.?;
    const runtime_services = uefi.system_table.runtime_services;
    const kernel_executable_path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\kernelx64");
    var status: uefi.Status = .Success;
    var root_file_system: *uefi.protocol.File = undefined;

    var memory_map: [*]uefi.tables.MemoryDescriptor = undefined;
    var memory_map_key: usize = 0;
    var memory_map_size: usize = 0;
    var descriptor_count: usize = undefined;
    var descriptor_size: usize = undefined;
    var descriptor_version: u32 = undefined;

    var framebuffer: u64 = undefined;
    var framebuffer_size: usize = undefined;
    var framebuffer_height: u32 = undefined;
    var framebuffer_width: u32 = undefined;
    var framebuffer_pixelsPerScanLine: u32 = undefined;

    var kernel_entry_point: u64 = undefined;
    var kernel_start_address: u64 = undefined;
    var kernel_entry: *const fn (BootInfo) callconv(.SysV) noreturn = undefined;
    var file_system: *uefi.protocol.SimpleFileSystem = undefined;

    if (config.debug == true) puts("Debug: Locating simple file system protocol\r\n");
    
    status = boot_services.locateProtocol(&uefi.protocol.SimpleFileSystem.guid, null, @as(*?*anyopaque, @ptrCast(&file_system)));
    if (status != .Success) {
        puts("Error: Locating simple file system protocol failed\r\n");
        return status;
    }

    if (config.debug == true) puts("Debug: Opening root volume\r\n");

    status = file_system.openVolume(&root_file_system);
    if (status != .Success) {
        puts("Error: Opening root volume failed\r\n");
        return status;
    }

    if (config.debug == true) puts("Debug: Getting memory map to find free addresses\r\n");

    while (boot_services.getMemoryMap(&memory_map_size, memory_map, &memory_map_key, &descriptor_size, &descriptor_version) == .BufferTooSmall) {
        status = boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, memory_map_size, @as(*[*]align(8) u8, @ptrCast(@alignCast(&memory_map))));
        if (status != .Success) {
            puts("Error: Allocating memory map failed\r\n");
            return status;
        }
    }
    if (status != .Success) {
        puts("Error: Getting memory map failed\r\n");
        return status;
    }
    if (config.debug == true) puts("Debug: Finding free kernel base address\r\n");

    var mem_index: usize = 0;
    var mem_point: *uefi.tables.MemoryDescriptor = undefined;
    var base_address: u64 = 0x100000;
    var num_pages: usize = 0;
    descriptor_count = memory_map_size / descriptor_size;

    if (config.debug == true) printf("Debug: descriptor_count is {}\r\n", .{descriptor_count});
    
    while (mem_index < descriptor_count) : (mem_index += 1) {
        if (config.debug == true) printf("Debug: mem_index is {}\r\n", .{mem_index});

        mem_point = @ptrFromInt(@intFromPtr(memory_map) + (mem_index * descriptor_size));

        if (mem_point.type == .ConventionalMemory and mem_point.physical_start >= base_address) {
            base_address = mem_point.physical_start;
            num_pages = mem_point.number_of_pages;
            if (config.debug == true) printf("Debug: Found {} free pages at 0x{x}\r\n", .{ num_pages, base_address });
            break;
        }
    }
    if (config.debug == true) puts("Debug: Loading kernel image\r\n");

    status = loader.loadKernelImage(
        root_file_system,
        kernel_executable_path,
        base_address,
        &kernel_entry_point,
        &kernel_start_address,
    );
    if (status != .Success) {
        puts("Error: Loading kernel image failed\r\n");
        return status;
    }
    
    if (config.debug == true) printf("Debug: Set Kernel Entry Point to: '0x{x}'\r\n", .{kernel_entry_point});
    
    if (config.debug == true) puts("Debug: Configuring graphics mode\r\n");

    var gop: ?*uefi.protocol.GraphicsOutput = undefined;
    status = boot_services.locateProtocol(
        &uefi.protocol.GraphicsOutput.guid,
        null,
        @ptrCast(&gop)
    );
    if (status != .Success) {
        puts("Error: Locate Graphics Output Protocol Failed\r\n");
        return status;
    }

    var info: *uefi.protocol.GraphicsOutput.Mode.Info = undefined;
    var info_size: usize = undefined;

    _ = gop.?.queryMode(gop.?.mode.mode, &info_size, &info);
    if (config.debug == true) printf("Debug: Video mode: {}: {}x{}px\r\n",
    .{gop.?.mode.mode, info.horizontal_resolution, info.vertical_resolution});

    framebuffer = gop.?.mode.frame_buffer_base;
    framebuffer_size = gop.?.mode.frame_buffer_size;
    framebuffer_height = info.vertical_resolution;
    framebuffer_width = info.horizontal_resolution;
    framebuffer_pixelsPerScanLine = info.pixels_per_scan_line;

    if (config.debug == true) puts("Debug: Allocating memory to memory map entries\r\n");
    var memory_map_entries: [*]structures.MemoryMapEntry = undefined;

    const size = num_pages * @sizeOf(structures.MemoryMapEntry);
    const seg_page_count = efi_aditional.efiSizeToPages(size);

    if (config.debug == true) printf("Debug: Allocating {} pages for Memory Map\r\n", .{seg_page_count});

    status = boot_services.allocatePool(
        .LoaderData,
        size,
        @as(*[*]align(8) u8, @alignCast(@ptrCast(&memory_map_entries)))
    );
    if (status != .Success) {
        puts("Error: Allocate memory to memory map Failed\r\n");
        return status;
    }
    if (config.debug == true) printf("Debug: Memory Map Entries being allocated in 0x{X:0>16}\r\n",
    .{@intFromPtr(memory_map_entries)});

    if (config.debug == true) puts("Debug: Disabling watchdog timer\r\n");

    status = boot_services.setWatchdogTimer(0, 0, 0, null);
    if (status != .Success) {
        puts("Error: Disabling watchdog timer failed\r\n");
        return status;
    }
    
    status = .NoResponse;
    while (status != .Success) {
        if (config.debug == true) puts("Getting memory map and trying to exit boot services\r\n");
        
        while (boot_services.getMemoryMap(&memory_map_size, memory_map, &memory_map_key, &descriptor_size, &descriptor_version) == .BufferTooSmall) {
            status = boot_services.allocatePool(.BootServicesData, memory_map_size, @as(*[*]align(8) u8, @ptrCast(@alignCast(&memory_map))));
            if (status != .Success) {
                puts("Error: Getting memory map failed\r\n");
                return status;
            }
        }
        
        status = boot_services.exitBootServices(uefi.handle, memory_map_key);
    }
    
    mem_index = 0;
    descriptor_count = memory_map_size / descriptor_size;
    while (mem_index < descriptor_count) : (mem_index += 1) {
        mem_point = @ptrFromInt(@intFromPtr(memory_map) + (mem_index * descriptor_size));
        if (mem_point.type == .LoaderData) {
            mem_point.virtual_start = kernel_start_address;
        } else {
            mem_point.virtual_start = mem_point.physical_start;
        }
    }

    status = runtime_services.setVirtualAddressMap(memory_map_size, descriptor_size, descriptor_version, memory_map);
    if (status != .Success) {
        return status;
    }

    var iterator = structures.MemMapIterator {
        .map_base = @intFromPtr(memory_map),
        .map_size = memory_map_size,
        .desc_size = descriptor_size
    };

    while(true) {
        const entry = iterator.next();
        if (entry) |e| {
            memory_map_entries[iterator.index-1] = e;
        } else break;
    }

    const framebuffer_data = FrameBuffer {
        .base_address = framebuffer,
        .size = framebuffer_size,
        .width = framebuffer_width,
        .height = framebuffer_height,
        .pixels_per_scan_line = framebuffer_pixelsPerScanLine
    };

    const bootInfo = BootInfo {
        .memory_map = @constCast(&memory_map_entries[0..descriptor_count]),
        .framebuffer = framebuffer_data
    };
    
    kernel_entry = @ptrFromInt(kernel_entry_point);
    kernel_entry(bootInfo);
    return .LoadError;
}

/// This is a wrapper to call the bootloader function.
pub fn main() void {
    var status: uefi.Status = .Success;
    status = bootloader();
    // The computer should never get here because everything should succeed.
    // But just in case anything happens, we print out the tag name of the status (for .LoadError it will be "LoadError").
    // In any function, we always print out "Error: xyz failed", so we have something like a stack trace.
    // Here, we just print out the error name that was responsible for that fail.
    puts("Status: ");
    puts(@tagName(status));
    puts("\r\n");
    while (true) {}
}
