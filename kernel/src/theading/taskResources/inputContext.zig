const os = @import("root").os;
const theading = os.theading;

const write = os.console_write("Input Context");
const st = os.stack_tracer;

pub const InputContextPool = extern struct {
    buffer_count: usize,
    buffer: [512]InputContextPoolItem,
};
pub const InputContextPoolItem = extern struct {
    event_kind: InputContextEventKind,
    data_pool: [15]u8,
};
pub const InputContextEventKind = enum(u8) {
    undefined = 0,
    keyboard = 1,
    mouse = 2,
};

const KeyboardState = @import("../../drivers/ps2/keyboard/state.zig");
const keyboard_state: KeyboardState = os.drivers.input_devices.keyboard;

pub fn CreateTaskInputContext(task: theading.Task) !*InputContextPool {
    st.push(@src());
    defer st.pop();

    if (task.input_context) |ctx| return ctx;

    // if not, allocate a new one
    var taskAllocator = task.taskAllocator.allocator();
    const ctx = try taskAllocator.create(InputContextPool);

    keyboard_state.register_input_context(ctx);

    return ctx;
}
