const std = @import("std");
const os = @import("root").os;

const TaskContext = os.theading.TaskContext;
const taskResources = os.theading.taskResources;

const write = os.console_write("Task");
const st = os.stack_tracer;

const ResourceHandler = os.system.ResourceHandler;
const Pipe = os.theading.Pipe;

const PipeMap = std.StringHashMap(Pipe);

const guard_size = os.theading.stack_guard_size;
const map_size = os.theading.task_stack_size;
const total_size = guard_size + map_size;

pub const Task = struct {
    name: [:0]u8,
    id: usize,
    state: TaskState,
    waitingFor: TaskWaitingDetails,

    entry_pointer: usize,
    args_pointer: usize,

    stack: []u8,
    stack_pointer: usize,

    stack_trace: [1024][128]u8,
    stack_trace_count: u16,

    context: TaskContext,
    resources: []ResourceHandler,

    stdio: *Pipe,
    pipes: PipeMap,

    taskAllocator: std.heap.ArenaAllocator,

    pub fn allocate_new() *Task {
        st.push(@src()); defer st.pop();

        const ptr = os.memory.allocator.create(Task) catch @panic("undefined error");

        // Create arena allocator
        ptr.taskAllocator = std.heap.ArenaAllocator.init(os.memory.allocator);
        // Create resources list
        ptr.resources = ptr.taskAllocator.allocator().alloc(ResourceHandler, 0x40) catch unreachable;
        // Create stdio pipe
        ptr.stdio = Pipe.init("stdio");
        // Create pipe map
        ptr.pipes = PipeMap.init(ptr.taskAllocator.allocator());

        { // stack trace config
            ptr.stack_trace_count = 3;

            ptr.stack_trace[0] = @constCast("*Interrupt 20 (32)" ++ [1]u8{0} ** 110).*;
            ptr.stack_trace[1] = @constCast("kernel/src/interruptions.zig:handle_timer_interrupt l.xxx" ++ [1]u8{0} ** 71).*;
            ptr.stack_trace[2] = @constCast("kernel/src/theading/schedue.zig:do_schedue l.xxx" ++ [1]u8{0} ** 80).*;}

        // Clear context
        ptr.context = std.mem.zeroes(TaskContext);

        return ptr;
    }

    pub fn destry(self: *@This()) void {
        _ = self;
    }

    pub fn alloc_stack(self: *@This()) !void {
        st.push(@src());
        defer st.pop();

        const allocator = self.taskAllocator.allocator();

        self.stack = try allocator.alloc(u8, total_size);
        errdefer allocator.free(self.stack);

        self.stack_pointer = @intFromPtr(&self.stack) + total_size;
    }

    pub fn get_resource_index(self: *@This()) !usize {
        st.push(@src()); defer st.pop();
        // TODO certainly a better way to make it more performatic

        for (0..self.resources.len) |i| {
            if (!self.resources[i].in_use) {
                self.resources[i].in_use = true;
                return i;
            }
        }

        // No free resource, allocating more
        const old_len = self.resources.len;
        _ = self.taskAllocator.allocator().realloc(self.resources, @truncate(self.resources.len * 2)) catch unreachable;

        return old_len;
    }
    pub fn free_resource_index(self: *@This(), handler: usize) !void {
        if (self.resources.len <= handler) return error.HandlerOutOfBounds;
        if (!self.resources[handler].in_use) return error.InvalidHandler;

        self.resources[handler].in_use = false;
    }

    pub fn format(self: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        try fmt.print("Task \"{s}\"\n", .{self.task_name});
        try fmt.print("stc: {}\n", .{self.stack_trace_count});
        try fmt.print("Context:\n{0}", .{self.context});
    }
};

pub const TaskState = enum {
    new,
    ready,
    running,
    awaiting,
};

pub const TaskWaitingDetailsTag = enum {
    pipe
};
pub const TaskWaitingDetails = union(TaskWaitingDetailsTag) {
    pipe: struct {
        pipePtr: *Pipe
    },
};
