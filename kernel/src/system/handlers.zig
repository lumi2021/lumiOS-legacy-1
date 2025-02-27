pub const ResourceHandler = struct {
    in_use: bool,
    data: union {
        file: ResourceHandlerData_File,
        device: ResourceHandlerData_Device,
        IO: ResourceHandlerData_IO,
    },
};

pub const ResourceHandlerData_Device = struct {};
pub const ResourceHandlerData_IO = struct {
    read: *fn () anyerror![]u8,
    write: *fn ([]u8) anyerror!void,
};

pub const ResourceHandlerData_File = struct {
    path: []u8,
    cursor: usize,

    // access flags
    read: bool,
    write: bool,
};
