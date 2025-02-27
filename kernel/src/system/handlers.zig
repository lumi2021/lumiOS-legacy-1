pub const ResourceHandler = struct {
    in_use: bool,
    data: union {
        file: ResourceHandlerData_File,
        sys_file: ResourceHandlerData_SysFile,
    }
};

pub const ResourceHandlerData_SysFile = struct {

};

pub const ResourceHandlerData_File = struct {
    path: []u8
};
