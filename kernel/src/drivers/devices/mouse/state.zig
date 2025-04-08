pub const os = @import("root").os;
pub const gl = os.gl;

pub var position: Point = undefined;
pub var buttons: [5]bool = undefined;


const print = os.console_write("mouse_state");
const st = os.stack_tracer;

pub fn init() void {
    @memset(&buttons, false);
    print.log("Mouse state initialized", .{});
}

pub inline fn set_button(button: Button, value: bool) void {
    st.push(@src()); defer st.pop();

    buttons[@intFromEnum(button)] = value;
}
pub inline fn get_button(button: Button) bool {
    st.push(@src()); defer st.pop();

    return buttons[@intFromEnum(button)];
}
pub fn move_delta(x: isize, y: isize) void {
    st.push(@src()); defer st.pop();

    position.x = @min(@max(0, position.x + x), gl.canvasPixelWidth);
    position.y = @min(@max(0, position.y + y), gl.canvasPixelHeight);

}

pub fn commit() void {
    st.push(@src()); defer st.pop();
    gl.move_cursor(position.x, position.y);
}


pub const Point = struct { x: isize, y: isize };
pub const Button = enum(u8) {
    left = 0,
    right = 1,
    middle = 2
};
