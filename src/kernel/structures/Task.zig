pub const TaskStateSegment = struct {
    reserved: u32,
    rsp: [3]u64,
    reserved2: u64,
    ist: [7]u64,
    reserved3: u64,
    reserved4: u16,
    io_map_base_address: u16,

    /// Inicializa um TSS vazio.
    pub fn init() TaskStateSegment {
        return TaskStateSegment{
            .reserved = 0,
            .rsp = [_]u64{0, 0, 0},
            .reserved2 = 0,
            .ist = [_]u64{0, 0, 0, 0, 0, 0, 0},
            .reserved3 = 0,
            .reserved4 = 0,
            .io_map_base_address = 0,
        };
    }
};

pub const TaskState = enum { New, Ready, Running, Waiting, Terminated };

pub const Task = struct {
    name: []const u8,
    tss: TaskStateSegment,
    stack: [4096]u8,
    state: TaskState,
    regs: [16]u64,

    pub fn init() Task {
        return Task{
            .name = "undef_task",
            .tss = TaskStateSegment.init(),
            .stack = [_]u8{0} ** 4096,
            .state = TaskState.New,
            .regs = [_]u64{0} ** 16,
        };
    }
};
