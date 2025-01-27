const os = @import("root").os;
const std = @import("std");

const log = os.console_write("keyboard state");

const kb = @import("keyboard.zig");

const PressedState = [@typeInfo(kb.keys.Location).@"enum".fields.len]bool;

const InputContext = os.theading.taskResources.inputContext;
const InputCtxList = std.ArrayList(*InputContext.InputContextPool);

var input_context_list: InputCtxList = undefined;

pub fn init() void {
    input_context_list = InputCtxList.init(os.memory.allocator);
}

pub fn register_input_context(ctx: *InputContext.InputContextPool) void {
    input_context_list.append(ctx) catch unreachable;
}
pub fn clean_input_context(ctx: *InputContext.InputContextPool) void {
    const items = input_context_list.items;
    var i: usize = 0;
    while (i < items.len) : (i += 1) {
        if (items[i] == ctx) {
            _ = input_context_list.orderedRemove(i);
            break;
        }
    }
}

fn pressedStateInit() PressedState {
    @setEvalBranchQuota(99999999);
    return std.mem.zeroes(PressedState);
}

pub const KeyboardState = struct {
    is_pressed: PressedState = pressedStateInit(),
    layout: kb.layouts.KeyboardLayout,

    pub fn pressed(self: *const @This(), location: kb.keys.Location) bool {
        return self.is_pressed[@intFromEnum(location)];
    }

    pub fn isShiftPressed(self: *const @This()) bool {
        return self.pressed(.left_shift) or self.pressed(.right_shift);
    }

    pub fn isAltPressed(self: *const @This()) bool {
        return self.pressed(.left_alt) or self.pressed(.right_alt);
    }

    pub fn isSuperPressed(self: *const @This()) bool {
        return self.pressed(.left_super) or self.pressed(.right_super);
    }

    pub fn isCtrlPressed(self: *const @This()) bool {
        return self.pressed(.left_ctrl) or self.pressed(.right_ctrl);
    }

    pub fn event(self: *@This(), t: kb.event.EventType, location: kb.keys.Location) !void {
        const input = try kb.layouts.getInput(self, location, self.layout);

        switch (t) {
            .press => {
                self.is_pressed[@intFromEnum(location)] = true;
            },
            .release => {
                self.is_pressed[@intFromEnum(location)] = false;
            },
        }

        const items = input_context_list.items;
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            const ctx = items[i];

            const last_idx = ctx.buffer_count;
            if (last_idx >= ctx.buffer.len) continue;

            var buffer = ctx.buffer;

            buffer[last_idx].event_kind = .keyboard;
            buffer[last_idx].data_pool[0] = @intFromEnum(location);
            buffer[last_idx].data_pool[1] = @intFromEnum(t);

            ctx.buffer_count += 1;
        }

        _ = input;
        //log.dbg("{s} {s}ed", .{ @tagName(input), @tagName(t) });
    }
};
