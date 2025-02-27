pub const ErrorCode = enum(usize) {
    NoError = 0,
    Undefined = 1,

    // Memory errors
    OutOfMemory,

    // File system errors
    PathNotFound,
    FileNotFound,
    AccessDenied,
};
