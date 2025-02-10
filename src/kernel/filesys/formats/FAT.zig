pub const BPB = extern struct {
    assembly_jump: [3]u8,
    oem_identifier: [8]u8,

    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    num_fats: u8,
    root_entries: u16, 
    total_sectors: u16,
    media_descriptor: u8,
    sectors_per_fat: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    total_sectors_large: u32,
};
