//! This is the core kernel loading functionality

// We have the imports from the standard library…
const std = @import("std");
const uefi = std.os.uefi;
const elf = std.elf;
// …and imports from our programs
const config = @import("./config.zig");
const text_out = @import("./text_out.zig");
const efi_additional = @import("./efi_additional.zig");
const puts = text_out.puts;
const printf = text_out.printf;

/// Read a UEFI file
pub fn readFile(
    /// This is our file we want to read
    file: *uefi.protocol.File,
    /// This is the start position we want to read from
    position: u64,
    /// How much we want to read
    size: usize,
    /// And the buffer we want to read into
    buffer: *[*]align(8) u8,
) uefi.Status {
    // Here we save the status
    var status: uefi.Status = .Success;
    // And we set the position in the file we want to read from
    status = file.setPosition(position);
    if (status != .Success) {
        puts("Error: Setting file position failed\r\n");
        return status;
    }
    // Now, we can read the file. The function in UEFI wants to have the size variable, but we don't.
    // So we @constCast it.
    // You may have recognized I return the status immediately (not saving it in the variable first).
    // That's because we already handled the setPosition status (so it will probably return there) and the read function is
    // the last thing we need to do here.
    return file.read(@constCast(&size), buffer.*);
}

/// Read a UEFI file and allocate free memory for it
pub fn readAndAllocate(
    /// This is our file we want to read
    file: *uefi.protocol.File,
    /// This is the start position we want to read from
    position: u64,
    /// How much we want to read
    size: usize,
    /// And the buffer we want to read into
    buffer: *[*]align(8) u8,
) uefi.Status {
    // We need the boot services to do that.
    const boot_services = uefi.system_table.boot_services.?;
    // Again, the status variable for saving each function's status.
    var status: uefi.Status = .Success;
    // Then, we allocate some memory for the file. However, the memory "type" we give the allocate function is a bit special:
    // We will never free this memory, as it holds the data of the kernel.
    status = boot_services.allocatePool(.LoaderData, size, buffer);
    if (status != .Success) {
        puts("Error: Allocating space for file failed\r\n");
        return status;
    }
    // As described above (in readFile), we just return the status of another function.
    return readFile(file, position, size, buffer);
}

/// Load an ELF program segment
pub fn loadSegment(
    /// This is the ELF file
    file: *uefi.protocol.File,
    /// This is the offset of the program segment we want to load
    segment_file_offset: u64,
    /// How big the segment is (in the file)
    segment_file_size: usize,
    /// How big the segment is (in the executable)
    segment_memory_size: usize,
    /// Where the segment will be stored in (virtual) memory
    segment_virtual_address: u64,
) uefi.Status {
    // Our status, as always
    var status: uefi.Status = .Success;
    // A small thing that ensures the segment virtual address is aligned to a page (4KB)
    if (segment_virtual_address & 4095 != 0) {
        puts("Warning: segment_virtual_address is not well aligned, returning with Success\r\n");
        return status;
    }
    // We get a segment buffer which we can write to. It has no upper boundary and has the start address of (segment_virtual_address).
    // NEVER DO THINGS LIKE THIS (arrays without upper boundaries) IF YOU AREN'T COMPLETELY SURE WHAT YOU ARE DOING!!!
    // (too many software vulnerabilities were caused by this problem…)
    // But here, we load the kernel, and if someone can modify the kernel, then that attacker will do many other things than exploiting this…
    var segment_buffer: [*]align(4096) u8 = @ptrFromInt(segment_virtual_address);
    // Because we will allocate pages (4KB regions of memory) and not bytes, we want to know the page count needed for this segment.
    const segment_page_count = efi_additional.efiSizeToPages(segment_memory_size);
    // Also, as the ELF documentation requests it, we need to zero-fill all unused bytes.
    // For that, we have to know where we should start zero-filling and how many bytes are going to be zero-filled.
    var zero_fill_start: u64 = 0;
    var zero_fill_count: usize = 0;
    const boot_services = uefi.system_table.boot_services.?;
    // At the beginning, we allocate pages for that program code. Why do we allocate pages and not single bytes?
    // Because the ELF specification requires that all "unused" bytes in a page are zero (and so we need control over them).
    if (config.debug == true) {
        printf("Debug: Allocating {} pages at address '0x{x}'\r\n", .{ segment_page_count, segment_virtual_address });
    }
    status = boot_services.allocatePages(
        .AllocateAddress,
        .LoaderData,
        segment_page_count,
        &segment_buffer,
    );
    if (status != .Success) {
        puts("Error: Allocating pages for ELF segment failed\r\n");
        return status;
    }
    // Now, we will read the segment data from the file directly into the segment buffer we just allocated,
    // but only if the segment file size is bigger than 0. This is a great example of the difference between
    // segment_file_size and segment_memory_size: Probably the program needs some memory that is already known
    // at compile-time, but there aren't any start values in the ELF file. So we have to allocate this part
    // of memory, but it will not contain any data (except for zeroes).
    if (segment_file_size > 0) {
        if (config.debug == true) {
            printf("Debug: Reading segment data with file size '0x{x}'\r\n", .{segment_file_size});
        }
        status = readFile(file, segment_file_offset, segment_file_size, &segment_buffer);
        if (status != .Success) {
            puts("Error: Reading segment data failed\r\n");
            return status;
        }
    }
    // Now, as you might have read above, we will zero-fill all unused space, but only if we have to zero-fill something
    // (if zero_fill_count is bigger than 0).
    zero_fill_start = segment_virtual_address + segment_file_size;
    zero_fill_count = segment_memory_size - segment_file_size;
    if (zero_fill_count > 0) {
        if (config.debug == true) {
            printf("Debug: Zero-filling {} bytes at address '0x{x}'\r\n", .{ zero_fill_count, zero_fill_start });
        }
        boot_services.setMem(@ptrFromInt(zero_fill_start), zero_fill_count, 0);
        puts("Debug: Zero-filling bytes succeeded\r\n");
    }
    return status;
}

/// Load all ELF program segments
pub fn loadProgramSegments(
    /// Our Kernel file
    file: *uefi.protocol.File,
    /// The ELF Program Headers (where we will get information about the program segments from)
    /// This is a slice, which is basically a pointer associated with a length.
    /// Because the information in a slice is not only the pointer, but also the length, it is basically the "safe many-item pointer".
    /// You can read about those problems at line 87 (in loadSegment the explanation for segment_buffer).
    program_headers: []const elf.Elf64_Phdr,
    /// The base physical address of the kernel
    base_physical_address: u64,
    /// A pointer to the address where the kernel entry point will be located.
    /// Because it's a pointer, we can write to it.
    kernel_start_address: *u64,
) uefi.Status {
    // Our status (again)
    var status: uefi.Status = .Success;
    // How many segments (described by program headers) we should load
    var n_segments_loaded: u64 = 0;
    // Used in the loop that iterates over the program headers
    var set_start_address: bool = true;
    // The difference between our base address (where free memory is, it can start at 0x100000) and the first loadable segment
    // (which is expected to be the kernel code).
    var base_address_difference: u64 = 0;
    // If the ELF file has no program headers, then the kernel is probably empty.
    if (program_headers.len == 0) {
        puts("Error: No program segments to load\r\n");
        return .InvalidParameter;
    }
    if (config.debug == true) {
        printf("Debug: Loading {} segments\r\n", .{program_headers.len});
    }
    // Because we have the program headers as a slice, we can easily iterate over it using "for".
    // If we used a many-item pointer, we would have to use a separate index.
    for (program_headers, 0..) |prog_hdr, i| {
        // We only load the segment if ELF tells us to do so.
        // There are some segments that are in the ELF file but that we don't have to load.
        if (prog_hdr.p_type == elf.PT_LOAD) {
            if (config.debug == true) {
                printf("Debug: Loading program segment {}\r\n", .{i});
            }
            // We can expect the first segment that will be loaded to be the kernel code segment.
            // Thus, we can do the following only the first time.
            if (set_start_address) {
                // When we enter this condition, set_start_address is true. If we set it to false,
                // we will not enter this condition another time. So we will enter this condition exactly once.
                set_start_address = false;
                // We set the kernel start address to the virtual address of that segment.
                kernel_start_address.* = prog_hdr.p_vaddr;
                // And we set the difference between the base address and the virtual address.
                base_address_difference = prog_hdr.p_vaddr - base_physical_address;
                if (config.debug == true) {
                    printf("Debug: Set kernel start address to 0x{x} and base address difference to 0x{x}\r\n", .{ kernel_start_address.*, base_address_difference });
                }
            }
            // Then, we call loadSegment which has the core loading functionality.
            status = loadSegment(
                // We give it the kernel executable…
                file,
                // …and some data from the program header
                prog_hdr.p_offset,
                prog_hdr.p_filesz,
                prog_hdr.p_memsz,
                prog_hdr.p_vaddr - base_address_difference,
            );
            if (status != .Success) {
                printf("Error: Loading program segment {} failed\r\n", .{i});
                return status;
            }
            // And if everything succeeded, we increase the number of segments that were loaded.
            // We need this because not all program segments want to be loaded, but we have to ensure that there is at least something.
            n_segments_loaded += 1;
        }
    }
    // We do not only have to return an error (above) if there are no segments we can iterate over,
    // but also if we find no loadable segments.
    if (n_segments_loaded == 0) {
        puts("Error: No loadable program segments found in executable\r\n");
        return .NotFound;
    }
    return status;
}

/// Load the kernel image
pub fn loadKernelImage(
    /// Pointer pointing to the root file system
    root_file_system: *uefi.protocol.File,
    /// UEFI (16-bit) string with the file name of the kernel
    kernel_image_filename: [*:0]const u16,
    /// Physical base address to load the bootloader
    base_physical_address: u64,
    /// Pointer to the "kernel_entry_point" variable to be set
    kernel_entry_point: *u64,
    /// Pointer to the "kernel_start_address" variable for virtual memory mapping
    kernel_start_address: *u64,
) uefi.Status {
    // The boot services
    const boot_services = uefi.system_table.boot_services.?;
    // You are probably tired of seeing this: Our status :-)
    var status: uefi.Status = .Success;
    // The kernel executable file.
    var kernel_img_file: *uefi.protocol.File = undefined;
    // And a buffer for the ELF Executable header, not to be confused with the program headers:
    //   - The Executable Header holds metadata for the entire executable
    //   - The Program Header holds (or the program headers hold) metadata for a program segment
    var header_buffer: [*]align(8) u8 = undefined;
    if (config.debug == true) {
        puts("Debug: Opening kernel image\r\n");
    }
    // As we want to do things with the kernel executable, we need to open the file.
    status = root_file_system.open(
        // A pointer to the kernel executable file
        &kernel_img_file,
        // The filename that (hopefully) exists in our root file system
        kernel_image_filename,
        // We want to open it read-only
        uefi.protocol.File.efi_file_mode_read,
        uefi.protocol.File.efi_file_read_only,
    );
    if (status != .Success) {
        puts("Error: Opening kernel file failed\r\n");
        return status;
    }
    // Now, we have to ensure that the kernel can be an ELF file.
    if (config.debug == true) {
        puts("Debug: Checking ELF identity\r\n");
    }
    // So we read the identity bytes of the kernel executable (also called image).
    status = readAndAllocate(kernel_img_file, 0, elf.EI_NIDENT, &header_buffer);
    if (status != .Success) {
        puts("Error: Reading ELF identity failed\r\n");
        return status;
    }
    // Now we check the ELF magic…
    if ((header_buffer[0] != 0x7f) or
        (header_buffer[1] != 0x45) or
        (header_buffer[2] != 0x4c) or
        (header_buffer[3] != 0x46))
    {
        puts("Error: Invalid ELF magic\r\n");
        return .InvalidParameter;
    }
    // …and we ensure that the kernel image is a 64bit one, not a 32bit or whatever one.
    if (header_buffer[elf.EI_CLASS] != elf.ELFCLASS64) {
        puts("Error: Can only load 64-bit binaries\r\n");
        return .Unsupported;
    }
    // Finally, we want to ensure that the kernel image is little-endian because that's how we are going to work with it.
    if (header_buffer[elf.EI_DATA] != elf.ELFDATA2LSB) {
        puts("Error: Can only load little-endian binaries\r\n");
        return .IncompatibleVersion;
    }
    // After we checked everything, we free the header buffer, so that we can allocate memory for it another time.
    status = boot_services.freePool(header_buffer);
    if (status != .Success) {
        puts("Error: Freeing ELF identity buffer failed\r\n");
        return status;
    }
    if (config.debug == true) {
        puts("Debug: ELF identity is good; continuing loading\r\n");
    }
    // Now, we will load the ELF header.
    if (config.debug == true) {
        puts("Debug: Loading ELF header\r\n");
    }
    // At first, we have to read the header from the executable and allocate memory for it.
    status = readAndAllocate(kernel_img_file, 0, @sizeOf(elf.Elf64_Ehdr), &header_buffer);
    if (status != .Success) {
        puts("Error: Reading ELF header failed\r\n");
        return status;
    }
    // Then, we parse the ELF header.
    // It contains informations such as the kernel entry point or informations about where the program headers will be.
    const header = elf.Header.parse(header_buffer[0..64]) catch |err| {
        // And here, we use Zig's native error handling system to translate the errors to UEFI-compatible errors.
        switch (err) {
            error.InvalidElfMagic => {
                puts("Error: Invalid ELF magic\r\n");
                return .InvalidParameter;
            },
            error.InvalidElfVersion => {
                puts("Error: Invalid ELF version\r\n");
                return .IncompatibleVersion;
            },
            error.InvalidElfEndian => {
                puts("Error: Invalid ELF endianness\r\n");
                return .IncompatibleVersion;
            },
            error.InvalidElfClass => {
                puts("Error: Invalid ELF endianness\r\n");
                return .IncompatibleVersion;
            },
        }
    };
    if (config.debug == true) {
        printf("Debug: Loading ELF header succeeded; entry point is 0x{x}\r\n", .{header.entry});
    }
    // If parsing the ELF header succeeds, we will save the entry point in the matching variable.
    // This is done by derefencing the pointer to the kernel entry point.
    // If you want to know why pointers are needed for mutable values in functions in Zig, take a look at the following video:
    // https://youtube.com/watch?v=8xjSvGd_IXU (relevant part at around 9:00 minutes).
    kernel_entry_point.* = header.entry;
    // Now we will load program headers.
    if (config.debug == true) {
        puts("Debug: Loading program headers\r\n");
    }
    // We need a buffer for the program header bytes.
    var program_headers_buffer: [*]align(8) u8 = undefined;
    // And we read the program headers and allocate space for them.
    status = readAndAllocate(kernel_img_file, header.phoff, header.phentsize * header.phnum, &program_headers_buffer);
    if (status != .Success) {
        puts("Error: Reading ELF program headers failed\r\n");
        return status;
    }
    // Now, we cast them into a more usable type (the program header type which allows us to access fields directly without doing binary magic :D).
    // And we slice that many-item pointer because a many-item pointer just says "Hey, the memory I am pointing to is something indexable and can have infinite entries"
    // but the slice says "Hey, the memory I am pointing to is something indexable and has N entries", so it is safer and we can iterate more easily over it.
    const program_headers = @as([*]const elf.Elf64_Phdr, @ptrCast(program_headers_buffer))[0..header.phnum];
    // And now, we call our helper function.
    status = loadProgramSegments(kernel_img_file, program_headers, base_physical_address, kernel_start_address);
    // To get finished, we close the kernel image file and free all memory we used for the header and program headers buffer.
    _ = kernel_img_file.close();
    _ = boot_services.freePool(header_buffer);
    _ = boot_services.freePool(program_headers_buffer);
    return status;
}
