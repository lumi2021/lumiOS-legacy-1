const root = @import("oslib.zig");
const raw_system_call = root.raw_system_call;

pub fn terminate_process(status: isize) void {
    
    _ = raw_system_call(0, status, 0, 0, 0);

}
