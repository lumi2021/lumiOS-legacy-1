const windowing = @import("windowing/windowing.zig");
const Win = windowing.Window;

var index: usize = 0;

pub var window: Win = Win.init();

pub fn set_index(idx: usize) !void {
    if (idx != 0) index = idx + 1
    else return error.indexAlreadyDefined;
}
pub fn get_index() usize {
    return index - 1;
}