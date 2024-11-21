const limine = @import("limine.zig");

pub export var framebuffer_request: limine.FramebufferRequest = .{};
pub export var memory_map_request: limine.MemoryMapRequest = .{};
pub export var kernel_addr_request: limine.KernelAddressRequest = .{};
pub export var hhdm_request: limine.HhdmRequest = .{};
pub export var base_revision: limine.BaseRevision = .{ .revision = 2 };

const BootInfo = @import("../structures/BootInfo.zig").BootInfo;
const Framebuffer = @import("../structures/BootInfo.zig").FrameBuffer;
const MMapEntry = @import("../structures/BootInfo.zig").MemoryMapEntry;

const kernel_entry = @import("../main.zig").main;

export fn __boot_entry__() callconv(.C) noreturn {

    if (framebuffer_request.response == null) done();
    if (framebuffer_request.response.?.framebuffer_count < 1) done();
    if (memory_map_request.response == null) done();
    if (kernel_addr_request.response == null) done();
    if (hhdm_request.response == null) done();

    const fbuffer = framebuffer_request.response.?.framebuffers_ptr[0];
    const mmap = memory_map_request.response.?;
    const addr = kernel_addr_request.response.?;
    const hhdr = hhdm_request.response.?;

    const boot_info = BootInfo {

        .kernel_physical_base = addr.physical_base,
        .kernel_virtual_base = addr.virtual_base,

        .hhdm_address_offset = hhdr.offset,

        .framebuffer = .{
            .framebuffer = fbuffer.address,
            .size = fbuffer.pitch * fbuffer.height,
            .width = fbuffer.width,
            .height = fbuffer.height,
            .pixels_per_scan_line = fbuffer.pitch,
        },

        .memory_map = @ptrCast(mmap.entries_ptr[0..mmap.entry_count])

    };

    kernel_entry(boot_info);

}

inline fn done() noreturn { while (true) { asm volatile ("hlt"); } }
