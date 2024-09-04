const std = @import("std");
const dbg = @import("IO/debug.zig");
const task_structs = @import("structures/Task.zig");
const TaskState = task_structs.TaskState;
const os = @import("OS/os.zig");

const TaskList = std.ArrayList(task_structs.Task);

var tasks: TaskList = undefined;
var current_task_idx: u64 = 0;

pub fn init() void {
    tasks = TaskList.init(os.allocator);
}

pub fn create_task(comptime task_name: []const u8, entry_point: fn() void) void {
    dbg.printf("Initing task \"{s}\"...\n", .{task_name});

    var task = task_structs.Task.init();
    task.name = @ptrCast(task_name);
    task.state = TaskState.Ready;
    task.regs[0] = @intFromPtr(&task.stack[task.stack.len - 1]);
    task.regs[15] = @intFromPtr(&entry_point);

    dbg.printf("Appending task \"{s}\" to task list...\n", .{task_name});
    tasks.append(task) catch unreachable;
}

pub fn switch_task(task: *task_structs.Task) void {
    dbg.printf("running task {s}\n", .{task.name});

    asm volatile ("mov %[ptr], %%rsp" :: [ptr] "r" (task.regs));
    //FIXME
    asm volatile ("iretq");
}

pub fn schedule() void {

    if (tasks.items.len == 0) return;
    
    dbg.printf("TC: {}; TI: {};\r\n", .{tasks.items.len, current_task_idx});

    while (current_task_idx < tasks.items.len) current_task_idx -= 1;
    var current_task: *task_structs.Task = &tasks.items[current_task_idx];

    dbg.printf("Halting \"{s}\"({})\r\n", .{ current_task.name, current_task_idx});
    current_task.state = TaskState.Ready;

    current_task_idx += 1;
    if (current_task_idx >= tasks.items.len) current_task_idx = 0;

    dbg.printf("Current task: {s} ({s})\r\n", .{current_task.name, @tagName(current_task.state)});

    if (current_task.state == TaskState.New)
        current_task.state = TaskState.Ready;

    if (current_task.state == TaskState.Ready) {
        current_task = &tasks.items[current_task_idx];
        current_task.state = TaskState.Running;
        switch_task(current_task);
    }
}
