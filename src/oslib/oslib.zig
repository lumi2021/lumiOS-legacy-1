pub const process = @import("process.zig");

pub fn raw_system_call(A: usize, B: usize, C: usize, D: usize, E: usize) usize {
    // FIXME support only fo intel

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
