pub const width = undefined;
pub const height = undefined;

var buffer: []u8 = undefined;


pub inline fn get_buffer_pointer() *[]u8 {
    return &buffer;
}


pub const WindowMode = enum {
    text,
    
};