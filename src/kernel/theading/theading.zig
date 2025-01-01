const os = @import("root").os;

pub const schedue = @import("schedue.zig");

pub const Task = @import("task.zig").Task;
pub const TaskContext = os.system.theading_task_context.TaskContext;

pub const run_process = schedue.run_process;

pub const task_stack_size: usize = 0x10000;
pub const stack_guard_size = 0x1000;
