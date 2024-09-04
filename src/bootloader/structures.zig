pub const BootInfo = extern struct {
    
    memory_map : *[]MemoryMapEntry,
    framebuffer : FrameBuffer

};
pub const MemoryMapEntry = extern struct {

    base_address: u64,
    size: u64,

    type: u32,
    attributes: u64,

};
pub const FrameBuffer = extern struct {

    base_address: u64,
    size: usize,
    width: u32,
    height: u32,
    pixels_per_scan_line: u32

};


pub const MemMapIterator = struct {
    map_base: usize,
    map_size: usize,
    desc_size: usize,

    index: usize = 0,

    pub fn next(iter: *@This()) ?MemoryMapEntry {
        const offset = iter.index * iter.desc_size;

        if (offset + iter.desc_size > iter.map_size)
            return null;

        const addr = iter.map_base + offset;
        iter.index += 1;

        const memDesc: *MemoryDescriptor = @ptrFromInt(addr);

        return MemoryMapEntry {
            .base_address = memDesc.physical_start,
            .size = memDesc.number_of_pages << 12,
            .attributes = memDesc.attribute,
            .type = memDesc.type
        };
    }

    const MemoryDescriptor = extern struct {
        type: u32,
        physical_start: u64,
        virtual_start: u64,
        number_of_pages: u64,
        attribute: u64,
    };
};
