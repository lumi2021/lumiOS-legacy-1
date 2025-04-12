const std = @import("std");
const os = @import("root").os;

const TaskContext = os.theading.TaskContext;
const taskResources = os.theading.taskResources;

const write = os.console_write("Pipe");
const st = os.stack_tracer;

pub const Pipe = struct {

    pub const PipeBuffer = std.fifo.LinearFifo([]u8, .Dynamic);

    name: []u8,
    allocator: std.mem.Allocator,
    buffer: PipeBuffer,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) *@This() {
        var this = allocator.create(Pipe) catch unreachable;

        this.allocator = allocator;
        this.name = allocator.alloc(u8, name.len) catch unreachable;
        this.name = @constCast(name);
        this.buffer = PipeBuffer.init(allocator);

        return this;
    }
    pub fn deinit(this: *@This()) void {
        const alloc = os.memory.allocator;

        alloc.free(this.name);
        this.buffer.deinit();
    }

    pub inline fn hasData(this: *@This()) bool {
        return this.buffer.count > 0;
    }

};
