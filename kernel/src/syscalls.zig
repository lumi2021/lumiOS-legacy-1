const root = @import("root");
const std = @import("std");
const os = root.os;
const ErrorCode = @import("osstd").ErrorCode;

const idtm = os.system.interrupt_manager;
const print = os.console_write("syscall");
const st = os.stack_tracer;

const taskman = os.theading.taskManager;
const schedue = os.theading.schedue;
const fs = os.fs;

const TaskContext = os.theading.TaskContext;

const SyscallVector = *const fn (*TaskContext, usize, usize, usize, usize) SyscallReturn;
const SyscallReturn = anyerror!usize;

var syscalls: [0xf][255]SyscallVector = undefined;

pub fn init() !void {
    st.push(@src()); defer st.pop();

    for (0..0xf) |i| { 
        inline for (0..255) |j| syscalls[i][j] = unhandled_syscall;
    }

    syscalls[0][0] = suicide;
    syscalls[0][1] = print_stdout;

    //syscalls[1][0] = mem_map;
    //syscalls[1][2] = mem_remap;
    //syscalls[1][3] = mem_free;

    syscalls[2][0] = open_file_descriptor;
    syscalls[2][1] = close_file_descriptor;
    syscalls[2][2] = write;
    syscalls[2][3] = read;

    syscalls[3][0] = branch_subprocess;

    idtm.interrupts[0x80] = syscall_interrupt;
}

pub fn syscall_interrupt(context: *TaskContext) void {
    st.push(@src()); defer st.pop();

    const group = context.rax >> 8;
    const call = context.rax & 0xff;

    print.dbg("System call 0x{X} of the group {X} requested!", .{group, call});

    const res = syscalls[group][call](context, context.rdi, context.rsi, context.rdx, context.r10) catch |err| {
        context.rbx = @intFromEnum(error_to_enum(err));
        return;
    };

    context.rax = res; // result in EAX
    context.rbx = 0;

    print.dbg("System call returned!", .{});
}
fn error_to_enum(err: anyerror) ErrorCode {
    return switch (err) {
        error.outOfMemory => .OutOfMemory,
        error.pathNotFound => .PathNotFound,
        error.fileNotFound => .FileNotFound,
        error.accessDenied => .AccessDenied,
        error.invalidDescriptor => .InvalidDescriptor,
        error.notAFile => .NotAFile,
        error.invalidPath => .InvalidPath,

        else => {
            print.warn("unhandled error: {s}", .{@errorName(err)});
            return .Undefined;
        },
    };
}

fn unhandled_syscall(ctx: *TaskContext, _: usize, _: usize, _: usize, _: usize) SyscallReturn {
    print.err("Invalid system call {X:0>2}", .{ctx.rax});
    return 0;
}

// Misc
fn suicide(_: *TaskContext, a: usize, _: usize, _: usize, _: usize) SyscallReturn {
    schedue.kill_current_process(@bitCast(a));
    return 0;
}
fn print_stdout(_: *TaskContext, message: usize, _: usize, _: usize, _: usize) SyscallReturn {
    const str_buf: [*:0]u8 = @ptrFromInt(message);
    const str: [:0]u8 = std.mem.span(str_buf);

    if (print.isModeEnabled(.Log)) {
        print.raw("[{s} ({X:0>5})] {s}", .{ os.theading.schedue.current_task.?.name, os.theading.schedue.current_task.?.id, str });
    }

    return 0;
}

// file operations
fn open_file_descriptor(_: *TaskContext, path_ptr: usize, flags: usize, _: usize, _: usize) SyscallReturn {
    const str_buf: [*:0]u8 = @ptrFromInt(path_ptr);
    var str_len: usize = 0;
    while (str_buf[str_len] != 0) : (str_len += 1) {}
    const str: [:0]u8 = str_buf[0..str_len :0];

    const res = try fs.open_file_descriptor(str, @bitCast(flags));

    return @bitCast(res);
}
fn close_file_descriptor(_: *TaskContext, handler: usize, _: usize, _: usize, _: usize) SyscallReturn {
    fs.close_file_descriptor(handler);
    return 0;
}
fn write(_: *TaskContext, handler: usize, buffer: usize, length: usize, pos: usize) SyscallReturn {
    const buf = @as([*]u8, @ptrFromInt(buffer))[0..length];
    try fs.write_file_descriptor(schedue.current_task.?, handler, buf, pos);

    return 0;
}
fn read(ctx: *TaskContext, handler: usize, buffer: usize, length: usize, pos: usize) SyscallReturn {
    const buf = @as([*]u8, @ptrFromInt(buffer))[0..length];
    try fs.read_file_descriptor(schedue.current_task.?, handler, buf, pos);

    schedue.do_schedue(ctx);
    return 0;
}

// process operations
fn branch_subprocess(_: *TaskContext, process_name: usize, entry_point: usize, args: usize, args_len: usize) SyscallReturn {
    const str_buf: [*:0]u8 = @ptrFromInt(process_name);
    const pname: [:0]u8 = std.mem.span(str_buf);

    const pargs: ?*anyopaque = @ptrFromInt(args);

    const pid = taskman.run_process(pname, @ptrFromInt(entry_point), pargs, args_len) catch unreachable;
    return pid;
}
