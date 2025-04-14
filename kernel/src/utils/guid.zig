const std = @import("std");

pub const Guid = extern struct {
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,

    pub fn is_zero(s: @This()) bool {
        return s.data1 == 0 and s.data2 == 0 and s.data3 == 0 and std.mem.eql(u8, &s.data4, &[_]u8{0} ** 8);
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{X:0>8}-{X:0>4}-{X:0>4}-{X:0>2}{X:0>2}-{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}",
            .{
                self.data1,
                self.data2,
                self.data3,
                self.data4[0], self.data4[1],
                self.data4[2], self.data4[3], self.data4[4],
                self.data4[5], self.data4[6], self.data4[7],
            },
        );
    }
};
