const os = @import("root").os;
const theading = @import("theading.zig");

const TaskContext = theading.TaskContext;

const write = os.console_write("Schedue");
const st = os.stack_tracer;

pub fn init() void {
    st.push(@src());

    write.log("Hello, Schedue!", .{});

    st.pop();
}

pub fn createTask(taskName: []u8, entry: anytype, args: anytype) !void {
    _ = taskName;
    _ = entry;
    _ = args;
}

fn change_task(currCtx: *TaskContext, newCtx: *TaskContext) void {
    _ = currCtx;
    _ = newCtx;
}

pub fn do_schedue(currContext: *TaskContext) void {
    st.push(@src());

    _ = currContext;

    st.pop();
}
