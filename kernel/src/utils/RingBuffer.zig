const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {

    return struct {
        items: [capacity]T = undefined,

        len: usize = 0,
        end: usize = 0,

        comptime capacity: usize = capacity,

        const Self = @This();

        pub inline fn is_full(s: *@This()) bool { return s.len == capacity; }

        pub fn append(self: *Self, new_item: T) void {
            self.items[self.end] = new_item;
            self.end += 1;

            if (self.end == capacity) self.end = 0;
        }
    };

}
