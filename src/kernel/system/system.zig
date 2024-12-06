pub const arch = @import("builtin").target.cpu.arch;

pub const interrupt_manager = @import("idtm.zig");

pub const sys_flags = switch (arch) {
    .x86_64 => @import("x86_64/asm_flags.zig"),
    .aarch64 => @import("arm64/asm_flags.zig"),
    else => unreachable,
};

pub const global_descriptor_table = switch (arch) {
    .x86_64 => @import("x86_64/GDT.zig"),
    .aarch64 => @import("arm64/GDT.zig"),
    else => unreachable,
};
pub const interrupt_descriptor_table = switch (arch) {
    .x86_64 => @import("x86_64/IDT.zig"),
    .aarch64 => @import("arm64/IDT.zig"),
    else => unreachable,
};

pub const theading_task_context = switch (arch) {
    .x86_64 => @import("x86_64/structs/task_context.zig"),
    .aarch64 => @import("arm64/structs/task_context.zig"),
    else => unreachable,
};

pub const memory_paging = switch (arch) {
    .x86_64 => @import("x86_64/paging.zig"),
    //.aarch64 => @import("arm64/paging.zig"),
    else => unreachable,
};
pub const memory_paging_entries = switch (arch) {
    .x86_64 => @import("x86_64/structs/page_entries.zig"),
    //.aarch64 => @import("arm64/structs/page_entries.zig"),
    else => unreachable,
};
