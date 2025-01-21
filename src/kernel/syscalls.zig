const root = @import("root");
const os = root.os;

const idtm = os.system.interrupt_manager;
const write = os.console_write("syscall");
const st = os.stack_tracer;

const schedue = os.theading.schedue;

const TaskContext = os.theading.TaskContext;

const SyscallVector = struct {
    function: fn (u64, u64, u64, u64, u64) u64
};

var syscalls: [255]SyscallVector = undefined;

pub fn init() !void {

    idtm.interrupts[0x80] = syscall_interrupt;

}

pub fn syscall_interrupt(context: *TaskContext) void {
    st.push(@src()); defer st.pop();

    write.log("System call requested!\n{}", .{context});

}
