const root = @import("root");
const os = root.os;

const idtm = os.system.interrupt_manager;
const write = os.console_write("syscall");
const st = os.stack_tracer;

const schedue = os.theading.schedue;

const TaskContext = os.theading.TaskContext;

const SyscallVector = *const fn (u64, u64, u64, u64) u64;

var syscalls: [255]SyscallVector = undefined;

pub fn init() !void {
    idtm.interrupts[0x80] = syscall_interrupt;

    inline for (0..255) |i| syscalls[i] = unhandled_syscall;

    syscalls[0x00] = syscall_00_kill_current_process;
    syscalls[0x01] = syscall_01_request_event_pool_context;
}

pub fn syscall_interrupt(context: *TaskContext) void {
    st.push(@src());
    defer st.pop();

    write.dbg("System call 0x{X} requested!", .{context.rax});
    context.rax = syscalls[context.rax](context.rdi, context.rsi, context.rdx, context.r10);
}

fn unhandled_syscall(_: u64, _: u64, _: u64, _: u64) u64 {
    write.err("Invalid system call", .{});
    return 0;
}

fn syscall_00_kill_current_process(a: u64, _: u64, _: u64, _: u64) u64 {
    schedue.kill_current_process(@bitCast(a));
    return 0;
}

fn syscall_01_request_event_pool_context(_: u64, _: u64, _: u64, _: u64) u64 {
    return 0;
}
