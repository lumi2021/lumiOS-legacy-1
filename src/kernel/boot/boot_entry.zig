const limine = @import("limine.zig");

pub export var framebuffer_request: limine.FramebufferRequest = .{};
pub export var memory_map_request: limine.MemoryMapRequest = .{};
pub export var kernel_addr_request: limine.KernelAddressRequest = .{};
pub export var hhdm_request: limine.HhdmRequest = .{};
pub export var base_revision: limine.BaseRevision = .{ .revision = 2 };

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

    _ = fbuffer;
    _ = mmap;
    _ = addr;
    _ = hhdr;

    kernel_entry();

}

inline fn done() noreturn { while (true) { asm volatile ("hlt"); } }