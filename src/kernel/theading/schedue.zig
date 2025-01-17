const std = @import("std");
const os = @import("root").os;
const theading = @import("theading.zig");

const Task = theading.Task;
const TaskContext = theading.TaskContext;

const write = os.console_write("Schedue");
const task_write = os.console_write("Task");
const st = os.stack_tracer;
const TaskList = std.ArrayList(*Task);

var task_list: TaskList = undefined;
var to_initialize_list: TaskList = undefined;

var task_idx: usize = 0;
var current_task: ?*Task = null;

var allocator: std.mem.Allocator = undefined;
var default_context: TaskContext = undefined;

const ProcessFunctionType = *const fn (?*anyopaque) callconv(.C) isize;

pub fn init() void {
    st.push(@src());

    allocator = os.memory.allocator;
    task_list = TaskList.init(allocator);
    to_initialize_list = TaskList.init(allocator);

    st.pop();
}

pub fn run_process(taskName: [:0]u8, entry: ProcessFunctionType, args: ?*anyopaque) !void {
    st.push(@src());

    write.dbg("Scheduing task \"{s}\" to be initialized...", .{taskName});

    const task = Task.allocate_new();
    try task.alloc_stack();

    task.task_name = taskName;
    task.entry_pointer = @intFromPtr(entry);
    task.args_pointer = @intFromPtr(args);

    try to_initialize_list.append(task);

    st.pop();
}

fn initialize_process(task: *Task) void {
    st.push(@src());

    task.context = default_context;

    task.context.rsp = task.stack_pointer;
    task.context.rbp = task.stack_pointer;

    task.context.rip = @intFromPtr(&process_handler);

    task.context.rdi = task.entry_pointer; // funcPtr
    task.context.rsi = task.args_pointer; // argsPtr

    task.context.eflags = 1 << 9;

    task_list.append(task) catch @panic("unexected");

    st.pop();
}

fn select_next_task() void {
    st.push(@src());

    write.dbg("w: {}; r {}; i: {}", .{ to_initialize_list.items.len, task_list.items.len, task_idx });

    if (to_initialize_list.items.len > 0) {
        const task = to_initialize_list.orderedRemove(0);
        initialize_process(task);
        current_task = task;
    } else if (task_list.items.len > 0) {
        task_idx = @min(task_idx, task_list.items.len - 1);
        current_task = task_list.items[task_idx];

        task_idx += 1;
        if (task_idx >= task_list.items.len) task_idx = 0;
    }

    st.pop();
}

pub fn do_schedue(currContext: *TaskContext) void {
    st.push(@src());

    write.dbg("Scheduing...", .{});
    if (task_list.items.len == 0 and to_initialize_list.items.len == 0) no_task_in_queue();

    // save current context
    if (current_task) |cTask| {
        write.dbg("Pausing task \"{s}\"...", .{cTask.task_name});
        cTask.context = currContext.*;
        st.pop();
        current_task = null;
    } else default_context = currContext.*;

    // change task
    select_next_task();

    // load new context
    if (current_task) |cTask| {
        write.dbg("Loading task \"{s}\"...", .{cTask.task_name});
        currContext.* = cTask.context;
        st.push_process(cTask.task_name);
    }

    st.pop();
}

fn no_task_in_queue() void {
    write.dbg("Nothing to do!", .{});
}

fn process_handler(funcPtr: usize, argsPtr: usize) callconv(.C) noreturn {
    task_write.dbg("p1: {X}; p2: {X}", .{ funcPtr, argsPtr });

    const entry: ProcessFunctionType = @ptrFromInt(funcPtr);
    const args: ?*anyopaque = @ptrFromInt(argsPtr);

    // calling
    const res = entry(args);
    task_write.dbg("Finishing task...", .{});
    task_write.dbg("Status code: {}", .{res});

    kill_current_process();
    while (true) {} // wait for scheduing
}

pub fn kill_current_process() void {
    os.system.sys_flags.clear_interrupt();
    st.push(@src());

    if (current_task) |curr| {
        for (0.., task_list.items) |i, e| {
            if (e == curr) _ = task_list.orderedRemove(i);
        }

        //os.memory.allocator.destroy(@as(*u8, @ptrFromInt(curr.args_pointer)));
    }

    st.pop();
    os.system.sys_flags.set_interrupt();
}
