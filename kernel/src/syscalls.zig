const root = @import("root");
const os = root.os;
const ErrorCode = @import("osstd").ErrorCode;

const idtm = os.system.interrupt_manager;
const write = os.console_write("syscall");
const st = os.stack_tracer;

const schedue = os.theading.schedue;
const fs = os.fs;

const TaskContext = os.theading.TaskContext;

const SyscallVector = *const fn (usize, usize, usize, usize) SyscallReturn;
const SyscallReturn = struct { err: ErrorCode, res: usize };

var syscalls: [255]SyscallVector = undefined;

pub fn init() !void {
    idtm.interrupts[0x80] = syscall_interrupt;

    inline for (0..255) |i| syscalls[i] = unhandled_syscall;

    syscalls[0x00] = syscall_00_kill_current_process;
    syscalls[0x01] = syscall_01_print_stdout;

    syscalls[0x02] = syscall_02_open_file_descriptor;
    syscalls[0x03] = syscall_03_close_file_descriptor;
    syscalls[0x04] = syscall_04_write;
}

pub fn syscall_interrupt(context: *TaskContext) void {
    st.push(@src());
    defer st.pop();

    write.dbg("System call 0x{X} requested!", .{context.rax});

    const res = syscalls[context.rax](context.rdi, context.rsi, context.rdx, context.r10);
    context.rax = res.res; // result in EAX
    context.rbx = @intFromEnum(res.err); // error in EBX

    write.dbg("System call returned!", .{});
}

fn unhandled_syscall(_: usize, _: usize, _: usize, _: usize) SyscallReturn {
    write.err("Invalid system call", .{});
    return .{ .res = 0, .err = .NoError };
}

fn syscall_00_kill_current_process(a: usize, _: usize, _: usize, _: usize) SyscallReturn {
    schedue.kill_current_process(@bitCast(a));
    return .{ .res = 0, .err = .NoError };
}

fn syscall_01_print_stdout(message: usize, _: usize, _: usize, _: usize) SyscallReturn {
    const str_buf: [*:0]u8 = @ptrFromInt(message);
    var str_len: usize = 0;
    while (str_buf[str_len] != 0) : (str_len += 1) {}
    const str: [:0]u8 = str_buf[0..str_len :0];

    os.GL.bcom.puts(str);

    return .{ .res = 0, .err = .NoError };
}

// file operations
fn syscall_02_open_file_descriptor(path_ptr: usize, flags: usize, _: usize, _: usize) SyscallReturn {
    const str_buf: [*:0]u8 = @ptrFromInt(path_ptr);
    var str_len: usize = 0;
    while (str_buf[str_len] != 0) : (str_len += 1) {}
    const str: [:0]u8 = str_buf[0..str_len :0];

    const res = fs.open_file_descriptor(str, @bitCast(flags)) catch |err|
        return .{ .res = 0, .err = error_to_enum(err) };

    return .{ .res = @bitCast(res), .err = .NoError };
}
fn syscall_03_close_file_descriptor(handler: usize, _: usize, _: usize, _: usize) SyscallReturn {
    fs.close_file_descriptor(handler);
    return .{ .res = 0, .err = .NoError };
}

fn syscall_04_write(handler: usize, bytes: usize, length: usize, pos: usize) SyscallReturn {

    _ = bytes;

    write.log("Request to write {} bytes in position {} of file {}", .{length, pos, handler});

    return .{ .res = 0, .err = .NoError };
}

fn error_to_enum(err: anyerror) ErrorCode {
    return switch (err) {
        error.outOfMemory => .OutOfMemory,
        error.pathNotFound => .PathNotFound,
        error.fileNotFound => .FileNotFound,
        error.accessDenied => .AccessDenied,

        else => .Undefined,
    };
}
