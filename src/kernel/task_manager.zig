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
    task.entry = @intFromPtr(&entry_point);
    task.state = TaskState.New;

    task.regs.rip = task.entry;
    task.regs.rbp = @intFromPtr(&task.stack[4095]) + 8;
    task.regs.rsp = task.regs.rbp;

    dbg.printf("Appending task \"{s}\" to task list...\n", .{task_name});
    tasks.append(task) catch unreachable;
}

pub fn pause_task(task: *task_structs.Task) void {
    task.state = .Ready;

    dbg.printf("pausing task {s}...\n", .{task.name});

    asm volatile ("mov %[ptr], %rsp" :: [ptr] "r" (task.regs));
    // TODO
    
    dbg.printf("{s} is paused.\n", .{task.name});
    asm volatile ("iretq");
}

pub fn load_task(task: *task_structs.Task) void {
    task.state = .Running;

    dbg.printf("running task {s}...\n", .{task.name});

    asm volatile ("mov %[context], %rsp" :: [context] "r" (&task.regs));
    asm volatile ("push %[prog_ptr]" :: [prog_ptr] "r" (task.regs.rip));

    asm volatile (
        \\ pop %rax
        \\ pop %rbx
        \\ pop %rcx
        \\ pop %rdx
        \\ pop %rdi
        \\ pop %rsi
        \\ pop %r8
        \\ pop %r9
        \\ pop %r10
        \\ pop %r11
        \\ pop %r12
        \\ pop %r13
        \\ pop %r14
        \\ pop %r15
        \\ pop %rbp
        \\ pop %rsp
    );
    
    dbg.printf("{s} is running!\n", .{task.name});
    asm volatile ("iretq");
}

pub fn schedule() void {

    if (tasks.items.len == 0) return;
    
    dbg.printf("Task Count: {}; Task Index: {};\r\n", .{tasks.items.len, current_task_idx});

    while (current_task_idx >= tasks.items.len) current_task_idx -= 1;
    var current_task: *task_structs.Task = &tasks.items[current_task_idx];

    if (tasks.items.len > 1) pause_task(current_task);

    current_task_idx += 1;
    if (current_task_idx >= tasks.items.len) current_task_idx = 0;

    current_task.log_formated();
    //dbg.printf("Current task: {s} ({s})\r\n", .{current_task.name, @tagName(current_task.state)});

    if (current_task.state != TaskState.Running) {

        current_task = &tasks.items[current_task_idx];
        load_task(current_task);

    }
}
