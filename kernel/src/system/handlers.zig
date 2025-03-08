const std = @import("std");
const os = @import("root").os;
const FsNode = os.fs.FsNode;

pub const ResourceHandler = struct {
    in_use: bool,

    fsnode: *FsNode,
    taskid: usize,

    data: ResourceHandlerData,

    pub const Kind = enum {
        // devices shit
        device,
        disk,

        // virtual shit
        file,
        directory,
        virtual_directory,
        symlink,
        pipe
    };
};

const ResourceHandlerData = union(ResourceHandler.Kind) {
    device: ResourceHandlerData_Device,
    disk: void,

    file: ResourceHandlerData_File,
    directory: void,
    virtual_directory: void,
    symlink: void,
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
