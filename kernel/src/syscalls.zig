const root = @import("root");
const os = root.os;
const ErrorCode = @import("osstd").ErrorCode;

const idtm = os.system.interrupt_manager;
const write = os.console_write("syscall");
const st = os.stack_tracer;

const schedue = os.theading.schedue;
const fs = os.fs;

const TaskContext = os.theading.TaskContext;

const SyscallVector = *const fn (*TaskContext, usize, usize, usize, usize) SyscallReturn;
const SyscallReturn = anyerror!usize;

var syscalls: [255]SyscallVector = undefined;

pub fn init() !void {
    idtm.interrupts[0x80] = syscall_interrupt;

    inline for (0..255) |i| syscalls[i] = unhandled_syscall;

    syscalls[0x00] = syscall_00_kill_current_process;
    syscalls[0x01] = syscall_01_print_stdout;

    syscalls[0x02] = syscall_02_open_file_descriptor;
    syscalls[0x03] = syscall_03_close_file_descriptor;
    syscalls[0x04] = syscall_04_write;
    syscalls[0x05] = syscall_05_read;
}

pub fn syscall_interrupt(context: *TaskContext) void {
    st.push(@src()); defer st.pop();

    write.dbg("System call 0x{X} requested!", .{context.rax});

    const res = syscalls[context.rax](
        context,
        context.rdi,
        context.rsi,
        context.rdx,
        context.r10
    )
    catch |err| {
        context.rbx = @intFromEnum(error_to_enum(err));
        return;
    };

    context.rax = res; // result in EAX
    context.rbx = 0;

    write.dbg("System call returned!", .{});
}
fn error_to_enum(err: anyerror) ErrorCode {
    return switch (err) {
        error.outOfMemory =>        .OutOfMemory,
        error.pathNotFound =>       .PathNotFound,
        error.fileNotFound =>       .FileNotFound,
        error.accessDenied =>       .AccessDenied,
        error.invalidDescriptor =>  .InvalidDescriptor,
        error.notAFile =>           .NotAFile,
        error.invalidPath =>        .InvalidPath,

        else => {
            write.warn("unhandled error: {s}", .{@errorName(err)});
            return .Undefined;
        }
    };
}

fn unhandled_syscall(ctx: *TaskContext, _: usize, _: usize, _: usize, _: usize) SyscallReturn {
    write.err("Invalid system call {X:0>2}", .{ctx.rax});
    return 0;
}


fn syscall_00_kill_current_process(_: *TaskContext, a: usize, _: usize, _: usize, _: usize) SyscallReturn {
    schedue.kill_current_process(@bitCast(a));
    return 0;
}

fn syscall_01_print_stdout(_: *TaskContext, message: usize, _: usize, _: usize, _: usize) SyscallReturn {
    const str_buf: [*:0]u8 = @ptrFromInt(message);
    var str_len: usize = 0;
    while (str_buf[str_len] != 0) : (str_len += 1) {}
    const str: [:0]u8 = str_buf[0..str_len :0];

    write.raw("[{s} ({X:0>5})] {s}", .{os.theading.schedue.current_task.?.name, os.theading.schedue.current_task.?.id, str});

    return 0;
}

// file operations
fn syscall_02_open_file_descriptor(_: *TaskContext, path_ptr: usize, flags: usize, _: usize, _: usize) SyscallReturn {
    const str_buf: [*:0]u8 = @ptrFromInt(path_ptr);
    var str_len: usize = 0;
    while (str_buf[str_len] != 0) : (str_len += 1) {}
    const str: [:0]u8 = str_buf[0..str_len :0];

    const res = try fs.open_file_descriptor(str, @bitCast(flags));

    return @bitCast(res);
}
fn syscall_03_close_file_descriptor(_: *TaskContext, handler: usize, _: usize, _: usize, _: usize) SyscallReturn {
    fs.close_file_descriptor(handler);
    return 0;
}
fn syscall_04_write(_: *TaskContext, handler: usize, buffer: usize, length: usize, pos: usize) SyscallReturn {
        const buf = @as([*]u8, @ptrFromInt(buffer))[0..length];
    try fs.read_file_descriptor(schedue.current_task.?, handler, buf, pos);

    return 0;
}
fn syscall_05_read(ctx: *TaskContext, handler: usize, buffer: usize, length: usize, pos: usize) SyscallReturn {
    const buf = @as([*]u8, @ptrFromInt(buffer))[0..length];
    try fs.read_file_descriptor(schedue.current_task.?, handler, buf, pos);

    schedue.do_schedue(ctx);
    return 0;
}
