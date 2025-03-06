const std = @import("std");
const os = @import("root").os;
const FsNode = os.fs.FsNode;

pub const ResourceHandler = struct {
    in_use: bool,

    fsnode: *FsNode,
    taskid: usize,

    data: ResourceHandlerData,

    pub const Kind = enum {
        file,
        directory,
        symlink,
        device,
        pipe
    };
};

const ResourceHandlerData = union(ResourceHandler.Kind) {
    file: ResourceHandlerData_File,
    directory: void,
    symlink: void,
    device: ResourceHandlerData_Device,
    pipe: ResourceHandlerData_Pipe,
};

pub const ResourceHandlerData_Device = struct {};
pub const ResourceHandlerData_Pipe = struct {
    pipePtr: *os.theading.Pipe
};

pub const ResourceHandlerData_File = struct {
    cursor: usize,

    // access flags
    read: bool,
    write: bool,
    execute: bool,
};
