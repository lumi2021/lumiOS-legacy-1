const std = @import("std");
const os = @import("root").os;
const theading = @import("theading.zig");

const gdt = os.system.global_descriptor_table;

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

var is_first_scheduing = true;

const ProcessFunctionType = *const fn (?*anyopaque) callconv(.C) isize;

pub fn init() void {
    st.push(@src());

    allocator = os.memory.allocator;
    task_list = TaskList.init(allocator);
    to_initialize_list = TaskList.init(allocator);

    st.pop();
}

pub fn run_process(taskName: [:0]u8, entry: ProcessFunctionType, args: ?*const anyopaque, argssize: usize) !void {
    st.push(@src());
    defer st.pop();

    write.dbg("Scheduing task \"{s}\" to be initialized...", .{taskName});

    const task = Task.allocate_new();
    try task.alloc_stack();

    const talloc = task.taskAllocator.allocator();

    if (argssize > 0) if (args) |a| {
        const argsptr = try talloc.alloc(u8, argssize);
        const argssrc = @as([*]u8, @constCast(@alignCast(@ptrCast(a))))[0..argssize];

        std.mem.copyForwards(u8, @constCast(argsptr), argssrc);

        task.args_pointer = @intFromPtr(argsptr.ptr);
    };

    task.task_name = taskName;
    task.entry_pointer = @intFromPtr(entry);

    try to_initialize_list.append(task);
}

fn initialize_process(task: *Task) void {
    st.push(@src());
    defer st.pop();

    task.context = default_context;

    task.context.rsp = task.stack_pointer;
    task.context.rbp = task.stack_pointer;

    task.context.rip = @intFromPtr(&process_handler);

    task.context.rdi = task.entry_pointer; // funcPtr
    task.context.rsi = task.args_pointer; // argsPtr

    task.context.eflags = 1 << 9;
    task.context.cs = gdt.selector.code64;
    task.context.ds = gdt.selector.data64;
    task.context.ss = gdt.selector.data64;
    task.context.es = gdt.selector.null;

    task_list.append(task) catch @panic("unexected");
}

fn select_next_task() void {
    st.push(@src());
    defer st.pop();

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
}

pub fn do_schedue(currContext: *TaskContext) void {
    st.push(@src());
    defer st.pop();

    write.dbg("Scheduing...", .{});

    if (task_list.items.len == 0 and to_initialize_list.items.len == 0) {
        no_task_in_queue(currContext);
        return;
    }

    // save current context
    if (current_task) |cTask| {
        write.dbg("Pausing task \"{s}\"...", .{cTask.task_name});
        cTask.context = currContext.*;
        current_task = null;
        st.pop();
    } else if (is_first_scheduing) {
        default_context = currContext.*;
        is_first_scheduing = false;
    }

    // change task
    select_next_task();

    // load new context
    if (current_task) |cTask| {
        write.dbg("Loading task \"{s}\"...", .{cTask.task_name});
        currContext.* = cTask.context;
        st.push_process(cTask.task_name);
    }
    // fallback to let it on hold
    else currContext.* = default_context;
}

fn no_task_in_queue(currContext: *TaskContext) void {
    write.dbg("Nothing to do!", .{});

    currContext.* = default_context;
}

fn process_handler(funcPtr: usize, argsPtr: usize) callconv(.C) noreturn {
    const entry: ProcessFunctionType = @ptrFromInt(funcPtr);
    const args: ?*anyopaque = @ptrFromInt(argsPtr);

    // calling
    const res = entry(args);

    // cleaning
    task_write.dbg("Finishing task... Status code: {}", .{res});

    kill_current_process();
}

pub fn kill_current_process() noreturn {
    st.push(@src());

    if (current_task) |curr| {
        for (0.., task_list.items) |i, e| {
            if (e == curr) _ = task_list.orderedRemove(i);
        }

        curr.taskAllocator.deinit();

        task_write.dbg("Task destroyed", .{});
    }
    current_task = null;

    task_write.dbg("forcing schedue...", .{});

    st.pop();
    asm volatile ("int $0x20");
    unreachable;
}
