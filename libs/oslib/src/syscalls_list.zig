pub const SysCalls = enum(u64) {

    suicide = 0,
    write_stdout = 1,

    open_file_descriptor = 2,
    close_file_descriptor = 3,
    _

};