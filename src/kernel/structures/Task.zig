const write = @import("../IO/debug.zig").write("Task");
const Context = @import("../interrupt_table.zig").InterruptFrame;
const libaligin = @import("../utils/libalign.zig");

const vmm = @import("../memory/vmm.zig");
const paging = @import("../memory/paging.zig");

pub const TaskStateSegment = struct {
    reserved: u32,
    rsp: [3]u64,
    reserved2: u64,
    ist: [7]u64,
    reserved3: u64,
    reserved4: u16,
    io_map_base_address: u16,

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

pub const stack_size = 0x10000;
pub const guard_size = 0x1000;
const total_size = guard_size + stack_size;

pub const Task = struct {
    name: []const u8,
    state: TaskState,

    entry: *NewTaskEntry,
    args: usize,
    stack: usize,
    frame: Context,

    tss: TaskStateSegment,

    pub fn init() Task {
        return Task{
            .name = "undef_task",
            .entry = undefined,
            .tss = TaskStateSegment.init(),
            .stack = 0,
            .state = TaskState.New,
            .frame = undefined,
            .args = undefined
        };
    }

    pub fn allocate_stack(self: *@This()) !void {
        write.dbg("dong shit", .{});
        const virt = @intFromPtr(try vmm.alloc_page());
        try paging.map_range(virt, virt, 1 << 12);

        write.dbg("vmm allocated 0x{X:0>16}", .{virt});
        self.stack = virt + total_size;
    }

    pub fn free_stack(self: *@This()) void {
        const virt = self.stack - total_size;
        vmm.free_page(virt);
    }


    pub fn log_formated(s: *@This()) void {
        write.log("Task {s} ({s}):", .{s.name, @tagName(s.state)});
        s.frame.log();
    }
};

pub const NewTaskEntry = struct {
    function: *const fn (*NewTaskEntry) noreturn,

    pub fn alloc(task: *Task, func: anytype, args: anytype) *NewTaskEntry {
        write.log("Allocating task entry...", .{});

        const ArgsT = @TypeOf(args);
        const FuncT = @TypeOf(func);

        write.log("Creating wrapper...", .{});
        const Wrapper = struct {
            entry: NewTaskEntry = .{ .function = invoke },
            function: *const FuncT,
            args: ArgsT,

            fn callWithErrorGuard(self: *@This()) !void {
                return @call(.never_tail, self.function, self.args);
            }

            fn invoke(entry: *NewTaskEntry) noreturn {
                write.log("Starting task...", .{});
                const self: *@This() = @fieldParentPtr("entry", entry);
                self.callWithErrorGuard() catch |err| {
                    write.log("Task finished with error {}!", .{err});
                };
                // Exit task here

                unreachable;
            }

            fn create(
                function: anytype,
                arguments: anytype,
                boot_stack_top: usize,
                boot_stack_bottom: usize
            ) *@This() {
                const addr = libaligin.alignDown(
                    usize,
                    @alignOf(@This()),
                    boot_stack_top - @sizeOf(@This())
                );

                const wrapper_ptr: *@This() = @ptrFromInt(addr);
                wrapper_ptr.* = .{
                    .function = function,
                    .args = arguments
                };

                _ = boot_stack_bottom;
                return wrapper_ptr;
            }

        };

        write.log("Configurating stack range...", .{});
        const stack_top = task.stack;

        write.log("task.stack: 0x{x:0>16}", .{task.stack});

        const stack_bottom: usize = stack_top - stack_size;
        write.log("0x{x:0>16} .. 0x{x:0>16}", .{stack_bottom, stack_top});

        return &Wrapper.create(
            func,
            args,
            stack_top,
            stack_bottom
        ).entry;
    }
};
