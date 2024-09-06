const dbg = @import("../IO/debug.zig");

pub const TaskStateSegment = struct {
    reserved: u32,
    rsp: [3]u64,
    reserved2: u64,
    ist: [7]u64,
    reserved3: u64,
    reserved4: u16,
    io_map_base_address: u16,

    pub fn init() TaskStateSegment {
        return TaskStateSegment{
            .reserved = 0,
            .rsp = [_]u64{0, 0, 0},
            .reserved2 = 0,
            .ist = [_]u64{0, 0, 0, 0, 0, 0, 0},
            .reserved3 = 0,
            .reserved4 = 0,
            .io_map_base_address = 0,
        };
    }
};

pub const TaskState = enum { New, Ready, Running, Waiting, Terminated };

pub const Task = struct {
    name: []const u8,
    entry: u64,
    tss: TaskStateSegment,
    stack: [4096]u8,
    state: TaskState,
    regs: TaskContext,

    pub fn init() Task {
        return Task{
            .name = "undef_task",
            .entry = 0,
            .tss = TaskStateSegment.init(),
            .stack = [_]u8{0} ** 4096,
            .state = TaskState.New,
            .regs = undefined,
        };
    }

    pub fn log_formated(s: *@This()) void {
        dbg.printf("Task {s} ({s}):\r\n", .{s.name, @tagName(s.state)});
        dbg.printf("entry: {X:0>16}\r\n", .{s.entry});
        dbg.printf("RAX={X:0>16} RBX={X:0>16} RCX={X:0>16} RDX={X:0>16}\r\n", .{s.regs.rax, s.regs.rbx, s.regs.rcx, s.regs.rdx});
        dbg.printf("RSI={X:0>16} RDI={X:0>16} RBP={X:0>16} RSP={X:0>16}\r\n", .{s.regs.rsi, s.regs.rdi, s.regs.rbp, s.regs.rsp});
        dbg.printf("R8 ={X:0>16} R9 ={X:0>16} R10={X:0>16} R11={X:0>16}\r\n", .{s.regs.r8, s.regs.r9, s.regs.r10, s.regs.r11});
        dbg.printf("R12={X:0>16} R13={X:0>16} R14={X:0>16} R15={X:0>16}\r\n", .{s.regs.r12, s.regs.r13, s.regs.r14, s.regs.r15});
        dbg.printf("RIP={X:0>16}\r\n", .{s.regs.rip});
    }
};

pub const TaskContext = packed struct {
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rdi: u64,
    rsi: u64,
    r8: u64,
    r9: u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    
    rbp: u64,
    rsp: u64,

    rip: u64,
};
