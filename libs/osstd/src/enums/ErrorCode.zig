pub const ErrorCode = enum(usize) {
    NoError = 0,
    Undefined = 1,

    //    general
    InvalidSyscall,
    InvalidDescriptor,

    // Memory errors
    OutOfMemory,

    // File system errors
    //    file
    FileNotFound,
    NotAFile,
    //    path
    PathNotFound,
    InvalidPath,
    //    permissions
    AccessDenied,
};
