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

        // data shit
        partition,
        file,
        directory,

        // virtual shit
        virtual_directory,
        symlink,
        pipe,
        sharedPipe
    };
};

const ResourceHandlerData = union(ResourceHandler.Kind) {
    device: ResourceHandlerData_Device,
    disk: void,

    partition: void,
    file: ResourceHandlerData_File,
    directory: void,
    
    virtual_directory: void,
    symlink: void,
    pipe: ResourceHandlerData_Pipe,
    sharedPipe: ResourceHandlerData_SharedPipe,
};

pub const ResourceHandlerData_Device = struct {};
pub const ResourceHandlerData_Pipe = struct {
    pipePtr: *os.theading.Pipe
};
pub const ResourceHandlerData_SharedPipe = struct {
    pipePtr: *os.theading.Pipe,
    bufferIdx: usize
};

pub const ResourceHandlerData_File = struct {
    // access flags
    read: bool,
    write: bool,
    execute: bool,
};
