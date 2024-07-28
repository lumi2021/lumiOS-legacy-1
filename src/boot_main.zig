const std = @import("std");
const uefi = std.os.uefi;
const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

const console = @import("./bootloader/console.zig");
const runtime = @import("./bootloader/runtime.zig");
const load_kernel_image = @import("./bootloader/elfLoader.zig").load_kernel_image;

const shared = @import("./util/shared/tables.zig");
const BootInfo = shared.BootInfo;
const FrameBuffer = shared.FrameBuffer;
const MemoryMapEntry = shared.MemoryMapEntry;

pub var boot_services: *uefi.tables.BootServices = undefined;
pub var runtime_services: *runtime.RuntimeServices = undefined;

pub fn main() uefi.Status {

    boot_services = uefi.system_table.boot_services.?;
    runtime_services = @ptrCast(uefi.system_table.runtime_services);
    console.out = uefi.system_table.con_out.?;

    var result = console.out.clearScreen();
    if (uefi.Status.Success != result) { return result; }

    console.puts("bootloader started\r\n");

    console.puts("configuring graphics mode...\r\n");
    var graphics_output_protocol: ?*uefi.protocol.GraphicsOutput = undefined;
    result = boot_services.locateProtocol(
        &uefi.protocol.GraphicsOutput.guid,
        null,
        @ptrCast(&graphics_output_protocol)
    );

    if (result != uefi.Status.Success) {
        console.puts("[error] unable to configure graphics mode\r\n");
        return result;
    }


    var info: *uefi.protocol.GraphicsOutput.Mode.Info = undefined;
    var info_size: usize = undefined;
    _ = graphics_output_protocol.?.queryMode(graphics_output_protocol.?.mode.mode, &info_size, &info);
    console.printf("current mode {}: {}x{}px\r\n",
    .{graphics_output_protocol.?.mode.mode, info.horizontal_resolution, info.vertical_resolution});

    const frame_buffer_address: u64 = graphics_output_protocol.?.mode.frame_buffer_base;
    const frame_buffer_len: usize = graphics_output_protocol.?.mode.frame_buffer_size;

    const frame_buffer_heigth = info.vertical_resolution;
    const frame_buffer_width = info.vertical_resolution;
    const frame_buffer_pixels_per_sline = info.pixels_per_scan_line;

    // obtain access to the file system
    console.puts("initialising File System service...");
    var simple_file_system: ?*uefi.protocol.SimpleFileSystem = undefined;
    result = boot_services.locateProtocol(
        &uefi.protocol.SimpleFileSystem.guid,
        null, @ptrCast(&simple_file_system)
    );
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf("ERROR {}: initialising file system\r\n", .{result});
        return result;
    }

    // Grab a handle to the FS volume
    var root_file_system: *uefi.protocol.File = undefined;
    result = simple_file_system.?.openVolume(&root_file_system);
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf("ERROR {}: opening file system volume\r\n", .{result});
        return result;
    }
    console.puts(" [done]\r\n");

    // Locate where there is some free memory
    console.puts("locating free memory...\r\n");
    var memory_map: [*]uefi.tables.MemoryDescriptor = undefined;
    var memory_map_size: usize = 0;
    var memory_map_key: usize = undefined;
    var descriptor_size: usize = undefined;
    var descriptor_version: u32 = undefined;

    // get the current memory map
    while (uefi.Status.BufferTooSmall == boot_services.getMemoryMap(
        &memory_map_size,
        memory_map,
        &memory_map_key,
        &descriptor_size,
        &descriptor_version)
    ) {
        result = boot_services.allocatePool(
            uefi.tables.MemoryType.BootServicesData,
            memory_map_size,
            @ptrCast(&memory_map)
        );
        if (uefi.Status.Success != result) { return result; }
    }

    console.printf("  -> memory map size: {}, descriptor size {}\r\n", .{memory_map_size, descriptor_size});

    var mem_index: usize = 0;
    var mem_count: usize = undefined;
    var mem_point: *uefi.tables.MemoryDescriptor = undefined;
    var base_address: u64 = 0x100000;
    var num_pages: usize = 0;

    mem_count = memory_map_size / descriptor_size;
    while (mem_index < mem_count) {
        mem_point = @ptrFromInt(@intFromPtr(memory_map) + (mem_index * descriptor_size));
        if (mem_point.type == uefi.tables.MemoryType.ConventionalMemory and mem_point.physical_start >= base_address) {
            base_address = mem_point.physical_start;
            num_pages = mem_point.number_of_pages;
            break;
        }
        mem_index += 1;
    }
    console.printf("  -> found {} pages at address ${X:8}\r\n", .{num_pages, base_address});
    console.puts("  -> [done]\r\n");

    // Start moving the kernel image into memory (\kernelx64.elf or \kernelaa64.elf)
    console.puts("loading kernel...\r\n");
    var entry_point: u64 = 0;
    var kernel_start: u64 = 0;

    result = load_kernel_image(
        root_file_system,
        utf16("kernelx64"),
        base_address,
        &entry_point,
        &kernel_start
    );
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf("ERROR {}: loading kernel\r\n", .{result});
        return result;
    }
    console.puts("  -> [done]\r\n");

    // prevent system reboot if we don't check-in
    console.puts("disabling watchdog timer...");
    result = boot_services.setWatchdogTimer(0, 0, 0, null);
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf("ERROR {}: disabling watchdog timer\r\n", .{result});
        return result;
    }
    console.puts(" [done]\r\n");

    //console.printf("graphics buffer: @{X}\r\n", .{graphics_output_protocol.?.mode.frame_buffer_base});
    console.printf("jumping to kernel... [${X:8}]\r\n", .{entry_point});

    // Attempt to exit boot services!
    console.puts("Exiting boot services...\r\n");

    result = uefi.Status.NoResponse;
    while(result != uefi.Status.Success) {
        // Get the memory map
        while (uefi.Status.BufferTooSmall == boot_services.getMemoryMap(
            &memory_map_size,
            memory_map,
            &memory_map_key,
            &descriptor_size,
            &descriptor_version
        )) {
            result = boot_services.allocatePool(
                uefi.tables.MemoryType.BootServicesData,
                memory_map_size,
                @ptrCast(&memory_map)
            );
            if (uefi.Status.Success != result) { return result; }
        }

        result = boot_services.exitBootServices(uefi.handle, memory_map_key);
    }

    const frameBuffer = FrameBuffer {
        .baseAddress = frame_buffer_address,
        .size = frame_buffer_len,
        .height = frame_buffer_heigth,
        .width = frame_buffer_width,
        .pixelsPerScanLine = frame_buffer_pixels_per_sline
    };

    const memMap = MemoryMapEntry {
        .size = memory_map_size,
        .key = memory_map_key,
        .desc_size = descriptor_size,
        .desc_ver = descriptor_version,
        .baseAddress = @intFromPtr(memory_map)
    };

     const boot_info = BootInfo{
        .framebuffer = frameBuffer,
        .memoryMap = memMap
    };

    // Put the boot information at the start of the kernel
    //const boot_info_ptr: *u64 = @ptrFromInt(base_address);
    //boot_info_ptr.* = @intFromPtr(&boot_info);

    // Prepare the memory map to be configured with virtual memory
    mem_index = 0;
    mem_count = memory_map_size / descriptor_size;
    while (mem_index < mem_count) {
        mem_point = @ptrFromInt(@intFromPtr(memory_map) + (mem_index * descriptor_size));

        // We want to change the virtual address of the loader data to match the ELF file
        // all other entries need their virtual addresses configured too
        if (mem_point.type == uefi.tables.MemoryType.LoaderData) {
            mem_point.virtual_start = kernel_start;
        } else {
            mem_point.virtual_start = mem_point.physical_start;
        }
        mem_index += 1;
    }

    // Configure the virtual memory
    result = runtime_services.setVirtualAddressMap(memory_map_size, descriptor_size, descriptor_version, memory_map);
    if (result != uefi.Status.Success) {
        return uefi.Status.LoadError;
    }

    const kernelEntry: *fn(BootInfo) callconv(.C) void = @ptrFromInt(entry_point);
    kernelEntry(boot_info);

    return uefi.Status.LoadError;
}
