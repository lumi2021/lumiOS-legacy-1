const os = @import("root").os;
const std = @import("std");
const schedue = os.theading.schedue;
const fs = os.fs;

const ProcessEntryFunction = os.theading.ProcessEntryFunction;
const Task = os.theading.Task;

const write = os.console_write("taskman");
const st = os.stack_tracer;

const TaskItem = ?*Task;
var task_list: []TaskItem = undefined;

var task_count: usize = 0;

var allocator: std.mem.Allocator = undefined;

pub fn init() void {
    st.push(@src()); defer st.pop();

    write.log("Initializing task manager...", .{});

    allocator = os.memory.allocator;
    task_list = allocator.alloc(TaskItem, 0x200) catch unreachable;
    @memset(task_list, null);
}

pub fn run_process(taskName: [:0]const u8, entry: ProcessEntryFunction, args: ?*const anyopaque, argssize: usize) !usize {
    st.push(@src()); defer st.pop();

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

    task.name = taskName;
    task.state = .new;
    task.entry_pointer = @intFromPtr(entry);

    const tid = get_first_free_tid();

    task.id = tid;
    task_list[tid] = task;
    task_count += 1;
    
    // create task virtual directory
    var buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&buf, "sys:/proc/{X:0>5}", .{tid}) catch unreachable;
    write.dbg("folder for process {} will be created in {s}", .{ tid, path });

    const procdir = fs.make_dir(path) catch unreachable;
    _ = procdir.branch("stdio", .{ .pipe = .{ .pipePtr = task.stdio } });

    return tid;
}

pub fn kill_process(tid: usize) void {
    st.push(@src());
    defer st.pop();

    os.system.sys_flags.clear_interrupt();
    defer os.system.sys_flags.clear_interrupt();

    const curr = getTask(tid) orelse return;
    task_list[tid] = null;
    task_count -= 1;

    curr.destry();
    curr.taskAllocator.deinit();

    var buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&buf, "sys:/proc/{X:0>5}", .{tid}) catch unreachable;
    write.dbg("removing directory {s}", .{ path });
    fs.remove(path) catch unreachable;

    write.dbg("Task destroyed", .{});
}

pub inline fn getTask(tid: usize) TaskItem {
    return task_list[tid];
}

pub inline fn activeTaskCount() usize {
    return task_count;
}
pub inline fn taskList_len() usize {
    return task_list.len;
}

pub fn get_first_free_tid() usize {
    st.push(@src()); defer st.pop();

    for (1..task_list.len) |i| {
        if (task_list[i] == null) return i;
    }

    // TODO increase thead list length
    unreachable;
}


pub fn lsproc() void {
    write.raw("{} active tasks\n", .{task_count});
    for (task_list) |i| if (i) |task| {
        write.raw("- {: <5} {s: <20} {s}\n", .{task.id, task.name, @tagName(task.state)});
    };
}
