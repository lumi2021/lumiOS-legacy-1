pub const SystemCall = @import("syscalls_list.zig").SysCalls;

pub const process = @import("process.zig");
pub const file = @import("file.zig");
pub const debug = @import("debug.zig");

pub fn raw_system_call(A: SystemCall, B: usize, C: usize, D: usize, E: usize) usize {
    // FIXME support only for intel

    var result: u64 = undefined;

    asm volatile (
        \\ int $0x80
        : [result] "=r" (result)
        : [rax] "{rax}" (A),
          [rdi] "{rdi}" (B),    
          [rsi] "{rsi}" (C),
          [rdx] "{rdx}" (D),
          [r10] "{r10}" (E),
        : "rcx", "r11", "memory"
    );

    return result;

}
