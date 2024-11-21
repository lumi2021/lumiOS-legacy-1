const std = @import("std");
const task_structs = @import("structures/Task.zig");
const TaskState = task_structs.TaskState;
const os = @import("OS/os.zig");

const gdt = @import("structures/GDT.zig");

const InterruptFrame = @import("interrupt_table.zig").InterruptFrame;

const TaskList = std.ArrayList(task_structs.Task);

var tasks: TaskList = undefined;
var current_task_idx: u64 = 0;

const write = @import("IO/debug.zig").write("Task Manager");

pub fn init() void {
    tasks = TaskList.init(os.allocator);
}

pub fn create_task(comptime task_name: []const u8, entry_point: anytype, args: anytype) !void {
    write.dbg("Initing task \"{s}\"...", .{task_name});

    var task = task_structs.Task.init();
    task.name = @ptrCast(task_name);
    task.state = TaskState.New;

    write.dbg("allocating task \"{s}\" stack...", .{task_name});
    try task.allocate_stack();
    errdefer {
        write.err("Error during page allocation!", .{});
        task.free_stack();
    }

    write.dbg("creating task \"{s}\" entry...", .{task_name});
    const tEntry = task_structs.NewTaskEntry.alloc(&task, entry_point, args);
    task.entry = tEntry;

    write.dbg("Appending task \"{s}\" to task list...", .{task_name});
    tasks.append(task) catch unreachable;
}


pub fn pause_task(task: *task_structs.Task, frame: *InterruptFrame) void {
    task.state = .Ready;

    write.dbg("pausing task {s}...", .{task.name});
    task.frame = frame.*;
    write.dbg("{s} is paused.", .{task.name});
}
pub fn load_task(task: *task_structs.Task, frame: *InterruptFrame) void {
    task.state = .Running;

    write.dbg("loading task {s}...", .{task.name});
    frame.* = task.frame;
    write.dbg("{s} is loaded.", .{task.name});
}
pub fn init_task(task: *task_structs.Task, frame: *InterruptFrame) !void {
    write.dbg("initializing task {s}...", .{task.name});

    task.frame.eflags = asm volatile (
        \\pushfq
        \\pop %[flags]
        : [flags] "=r" (-> u64)
    );

    task.frame.rbp = task.stack;
    task.frame.rsp = task.frame.rbp;

    task.frame.cs = gdt.selector.code64;
    task.frame.ss = gdt.selector.data64;
    task.frame.es = gdt.selector.data64;
    task.frame.ds = gdt.selector.data64;

    task.frame.rip = @intFromPtr(task.entry.function);

    frame.* = task.frame;
    task.state = .Running;
}

pub fn schedule(frame: *InterruptFrame) void {

    write.dbg("Before:", .{});
    frame.log();

    write.dbg("Task Count: {}; Task Index: {};", .{tasks.items.len, current_task_idx});

    if (tasks.items.len == 0) return;

    while (current_task_idx >= tasks.items.len) current_task_idx -= 1;
    var current_task: *task_structs.Task = &tasks.items[current_task_idx];

    if (current_task.state == .Running and tasks.items.len > 1)
        pause_task(current_task, frame);

    current_task_idx += 1;
    if (current_task_idx >= tasks.items.len) current_task_idx = 0;

    current_task = &tasks.items[current_task_idx];

    if (current_task.state == TaskState.Ready) {
        load_task(current_task, frame);
    
    } else if (current_task.state == TaskState.New) {
        init_task(current_task, frame) catch unreachable;
    }

    current_task.log_formated();

    write.dbg("After:", .{});
    frame.log();

    write.dbg("Returning process...", .{});
}
