const std = @import("std");
const os = @import("root").os;

const TaskContext = os.theading.TaskContext;
const TaskEntry = os.theading.TaskEntry;

const write = os.console_write("Task");
const st = os.stack_tracer;

const guard_size = os.theading.stack_guard_size;
const map_size = os.theading.task_stack_size;
const total_size = guard_size + map_size;

pub const Task = struct {
    task_name: [:0]u8,

    entry_pointer: usize,
    args_pointer: usize,

    stack: []u8,
    stack_pointer: usize,

    context: TaskContext,

    pub fn allocate_new() *Task {
        st.push(@src());

        const ptr = os.memory.allocator.create(Task) catch @panic("undefined error");
        ptr.context = std.mem.zeroes(TaskContext);

        st.pop();
        return ptr;
    }

    pub fn alloc_stack(self: *@This()) !void {
        st.push(@src());

        self.stack = try os.memory.allocator.alloc(u8, total_size);
        errdefer os.memory.allocator.free(self.stack);

        self.stack_pointer = @intFromPtr(&self.stack) + total_size;

        st.pop();
    }

    pub fn format(self: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        try fmt.print("Task \"{s}\"\n", .{self.task_name});
        try fmt.print("Context:\n{0}", .{self.context});
    }
};
