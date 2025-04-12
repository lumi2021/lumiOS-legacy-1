pub const MouseEvent = extern struct {
    left_button: bool,
    middle_button: bool,
    right_button: bool,

    wheel_delta_x: i32,
    wheel_delta_y: i32,

    position_delta_x: i32,
    position_delta_y: i32,

    position_X: usize,
    position_y: usize
};
