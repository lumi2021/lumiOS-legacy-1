pub const SystemCall = enum(usize) {

    suicide = 0,
    write_stdout = 1,

    open_file_descriptor = 2,
    close_file_descriptor = 3,
    write = 4,
    read = 5,
    
    branch_subprocess = 6,
    _
};
