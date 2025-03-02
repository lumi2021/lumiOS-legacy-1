pub const SystemCall = @import("enums/SystemCall.zig").SystemCall;
pub const ErrorCode = @import("enums/ErrorCode.zig").ErrorCode;

pub const fs = @import("fs/fs.zig");

pub const process = @import("process/process.zig");
pub const debug = @import("debug/debug.zig");

pub export fn doSystemCall(A: SystemCall, B: usize, C: usize, D: usize, E: usize) FailableUsize {
    // FIXME support only for intel

    var result: u64 = undefined;
    var err: ErrorCode = undefined;

    asm volatile (
        \\ int $0x80
        : [result] "={rax}" (result),
          [err] "={rbx}" (err),
        : [rax] "{rax}" (A),
          [rdi] "{rdi}" (B),
          [rsi] "{rsi}" (C),
          [rdx] "{rdx}" (D),
          [r10] "{r10}" (E),
        : "rbx", "rcx", "r11", "memory"
    );

    return .{ .err = err, .res = result };
}

pub const FailableUsize = extern struct { err: ErrorCode, res: usize };
