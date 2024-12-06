const std = @import("std");
const os = @import("root").os;
const writer = os.console_write("task context");

pub const TaskContext = extern struct {
    es: u64,
    ds: u64,
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rdi: u64,
    rsi: u64,
    rbp: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,
    intnum: u64,
    ec: u64,
    rip: u64,
    cs: u64,
    eflags: u64,
    rsp: u64,
    ss: u64,

    pub fn format(self: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        try fmt.print("  rax={X:0>16} rbx={X:0>16} rcx={X:0>16} rdx={X:0>16}\n", .{ self.rax, self.rbx, self.rcx, self.rdx });
        try fmt.print("  rsi={X:0>16} rdi={X:0>16} rbp={X:0>16} rsp={X:0>16}\n", .{ self.rsi, self.rdi, self.rbp, self.rsp });
        try fmt.print("  r8 ={X:0>16} r9 ={X:0>16} r10={X:0>16} r11={X:0>16}\n", .{ self.r8, self.r9, self.r10, self.r11 });
        try fmt.print("  r12={X:0>16} r13={X:0>16} r14={X:0>16} r15={X:0>16}\n", .{ self.r12, self.r13, self.r14, self.r15 });
        try fmt.print("  rip={X:0>16} int={X:0>16} ec ={X:0>16} cs ={X:0>16}\n", .{ self.rip, self.intnum, self.ec, self.cs });
        try fmt.print("  ds ={X:0>16} es ={X:0>16} flg={X:0>16}\n", .{ self.ds, self.es, self.eflags });
    }
};
