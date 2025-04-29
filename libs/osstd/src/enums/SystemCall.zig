pub const SystemCall = enum(usize) {

    suicide =                   0x0_00,
    write_stdout =              0x0_01,

    memory_map =                0x1_00,
    memory_remap =              0x1_01,
    memory_free =               0x1_02,

    open_file_descriptor =      0x2_00,
    close_file_descriptor =     0x2_01,
    write =                     0x2_02,
    read =                      0x2_03,
    
    branch_subprocess =         0x3_00,
    _
};
