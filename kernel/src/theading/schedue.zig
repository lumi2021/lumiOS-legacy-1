const std = @import("std");
const os = @import("root").os;
const theading = @import("theading.zig");
const task_manager = @import("taskManager.zig");

const gdt = os.system.global_descriptor_table;

const Task = theading.Task;
const TaskContext = theading.TaskContext;

const write = os.console_write("schedue");
const task_write = os.console_write("task");
const st = os.stack_tracer;

var task_idx: usize = 0;
pub var current_task: ?*Task = null;

var allocator: std.mem.Allocator = undefined;
var default_context: TaskContext = undefined;

var is_first_scheduing = true;

const ProcessEntryFunction = os.theading.ProcessEntryFunction;

fn initialize_process(task: *Task) void {
    st.push(@src()); defer st.pop();

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

    task.state = .ready;
}

fn select_next_task() void {
    if (task_idx + 1 >= task_manager.taskList_len()) task_idx = 0 else task_idx += 1;

    while (task_manager.getTask(task_idx) == null) {
        if (task_idx + 1 >= task_manager.taskList_len()) task_idx = 0 else task_idx += 1;
    }

    const task = task_manager.getTask(task_idx).?;

    if (task.state == .new) {
        write.log("unitialized task {}. initializing...", .{task.id});
        initialize_process(task);
    }
    current_task = task;
}

pub fn do_schedue(currContext: *TaskContext) void {
    st.enabled = false;
    defer st.enabled = true;

    write.dbg("Scheduing...", .{});

    if (task_manager.activeTaskCount() == 0) {
        no_task_in_queue(currContext);
        return;
    } //else if (task_manager.getTheadCount() == 1 and current_task != null) return;

    // save current context
    if (current_task) |cTask| {
        write.dbg("Pausing task \"{s}\"...", .{cTask.name});

        cTask.context = currContext.*;
        current_task = null;

        write.dbg("Task \"{s}\" paused.", .{cTask.name});
    } else if (is_first_scheduing) {
        write.dbg("Saving halted state...", .{});
        default_context = currContext.*;
        is_first_scheduing = false;
    }

    // change task
    select_next_task();

    // load new context
    if (current_task) |cTask| {
        write.dbg("Loading task \"{s}\"...", .{cTask.name});

        currContext.* = cTask.context;
        st.load_task_stack_trace(cTask);

        write.dbg("Task \"{s}\" loaded.", .{cTask.name});
    }
    // fallback to let it on hold
    else currContext.* = default_context;

    write.dbg("Resuming task...", .{});
}

fn no_task_in_queue(currContext: *TaskContext) void {
    write.dbg("Nothing to do!", .{});
    currContext.* = default_context;
}

fn process_handler(funcPtr: usize, argsPtr: usize) callconv(.C) noreturn {
    const entry: ProcessEntryFunction = @ptrFromInt(funcPtr);
    const args: ?*anyopaque = @ptrFromInt(argsPtr);

    // calling
    st.push_process(@constCast("__start"));
    const res = entry(args);

    // cleaning
    task_write.dbg("Finishing task... Status code: {}", .{res});

    st.pop();
    kill_current_process_noreturn(res);
}

pub fn kill_current_process_noreturn(status_code: isize) noreturn {
    st.push(@src()); defer st.pop();

    kill_current_process(status_code);

    task_write.dbg("forcing schedue...", .{});

    asm volatile ("int $0x20");
    unreachable;
}
pub fn kill_current_process(status_code: isize) void {
    st.push(@src()); defer st.pop();

    _ = status_code;

    if (current_task) |curr| task_manager.kill_process(curr.id);
    current_task = null;
}
