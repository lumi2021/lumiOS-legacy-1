const root = @import("../osstd.zig");
const raw_system_call = root.raw_system_call;

pub const ProcessEntryFunction = *const fn (?*anyopaque) callconv(.C) isize;

pub fn terminate_process(status: isize) noreturn {
    // This one needs to be manually called as it cannot return
    asm volatile (
        \\ mov $0, %rax
        \\ int $0x80
        :
        : [rdi] "{rdi}" (status),
    );
    while (true) {}
}

pub fn create_thead(name: []const u8, entry: ProcessEntryFunction, args: anytype) usize {
    if (@typeInfo(@TypeOf(args)) != .optional and
    @typeInfo(@TypeOf(args)) != .@"null") @panic("arguments must be a pointer!");

    const name_ptr: usize = @intFromPtr(name.ptr);
    const entry_ptr: usize = @intFromPtr(entry);
    const args_ptr: usize = if (args == null) 0 else
        @intFromPtr(@as(*anyopaque, @ptrCast(@alignCast(args))));
    const args_size: usize = if (args == null) 0 else @sizeOf(@TypeOf(args));

    const res = root.doSystemCall(
        .branch_subprocess,
        name_ptr,
        entry_ptr,
        args_ptr,
        args_size
    );

    if (res.err != .NoError) {
        @panic("errors not handled");
    }

    return res.res;
}
