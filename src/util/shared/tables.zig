pub const MemoryMapEntry = extern struct {
    baseAddress: u64,
    size: u64,
    key: u64,

    desc_size: usize,
    desc_ver: u32,
};

pub const FrameBuffer = extern struct {
    baseAddress: u64,
    size: usize,
    width: u32,
    height: u32,
    pixelsPerScanLine: u32,
};

pub const BootInfo = extern struct {
    memoryMap: MemoryMapEntry,
    framebuffer: FrameBuffer,
};
