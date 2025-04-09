const os = @import("root").os;
const std = @import("std");
const SourceLocation = std.builtin.SourceLocation;

var root_stack_trace: [1024][128]u8 = undefined;

var stack_trace: ?*[1024][128]u8 = &root_stack_trace;
var clean_buf: [128]u8 = undefined;
var stack_trace_count: u16 = 0;

const write = os.console_write("stack_tracer");

pub var enabled: bool = true;
var force_disable: bool = true;

pub inline fn push(src: SourceLocation) void {
    if (!enabled or force_disable or stack_trace == null) return;
    stack_trace.?[stack_trace_count] = clean_buf;
    _ = (std.fmt.bufPrint(&stack_trace.?[stack_trace_count], "{s}:{s} l.{}" ++ .{0}, .{ src.file, src.fn_name, src.line }) catch @panic("No space left!"));

    stack_trace_count += 1;
    if (stack_trace_count >= 1024) @panic("Stack overflow!");
}

pub inline fn push_process(task_name: [:0]u8) void {
    if (!enabled or force_disable or stack_trace == null) return;
    stack_trace.?[stack_trace_count] = clean_buf;
    _ = (std.fmt.bufPrint(&stack_trace.?[stack_trace_count], "Process {s}" ++ .{0}, .{task_name}) catch @panic("No space left!"));

    stack_trace_count += 1;
    if (stack_trace_count >= 1024) @panic("Stack overflow!");
}

pub inline fn push_interrupt(int_num: u64) void {
    if (!enabled or force_disable or stack_trace == null) return;
    stack_trace.?[stack_trace_count] = clean_buf;
    _ = std.fmt.bufPrint(&stack_trace.?[stack_trace_count], "*Interrupt {0X:0>2} ({0})" ++ .{0}, .{int_num}) catch @panic("No space left!");

    stack_trace_count += 1;
    if (stack_trace_count >= 1024) @panic("Stack overflow!");
}

pub fn pop() void {
    if (!enabled or force_disable or stack_trace == null) return;
    stack_trace_count -= 1;
}

pub fn get_stack_trace() [][128]u8 {
    return stack_trace.?[0..stack_trace_count];
}

pub fn load_task_stack_trace(task: *os.theading.Task) void {
    write.dbg("Loading stack trace from {s} ({} itens)", .{ task.name, task.stack_trace_count });
    stack_trace = &task.stack_trace;
    stack_trace_count = task.stack_trace_count;
}
