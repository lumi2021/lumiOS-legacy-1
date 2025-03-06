const std = @import("std");

pub const ResourceHandler = struct {
    in_use: bool,
    path: []u8,
    taskid: usize,

    data: union(Kind) {
        file: ResourceHandlerData_File,
        directory: void,
        symlink: void,
        device: ResourceHandlerData_Device,
        pipe: ResourceHandlerData_Pipe,
    },


    pub const Kind = enum {
        file,
        directory,
        symlink,
        device,
        pipe
    };
};

pub const ResourceHandlerData_Device = struct {};
pub const ResourceHandlerData_Pipe = struct {
    
};

pub const ResourceHandlerData_File = struct {
    cursor: usize,

    // access flags
    read: bool,
    write: bool,
    execute: bool,
};
