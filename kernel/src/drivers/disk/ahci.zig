const std = @import("std");
const os = @import("root").os;
const disk = os.drivers.disk;
const pci = os.drivers.pci;
const fs = os.fs;
const mem = os.memory;

const write = os.console_write("aHCI");
const st = os.stack_tracer;

const HBA_PxCMD_ST   = 0x0001;
const HBA_PxCMD_FRE  = 0x0010;
const HBA_PxCMD_FR   = 0x4000;
const HBA_PxCMD_CR   = 0x8000;

pub fn init_device(addr: pci.Addr) void {
    st.push(@src()); defer st.pop();

    _ = addr;
}

pub fn read(device: *AHCIDeviceEntry, sector: u64, buffer: []u8) !void {
    st.push(@src()); defer st.pop();

    _ = device;
    _ = sector;
    _ = buffer;
}

pub const AHCIDevice = enum {
    _null,
    sata,
    semb,
    pm,
    satapi
};

pub const FISType = enum(u8) {
    FIS_TYPE_REG_H2D	= 0x27,	// Register FIS - host to device
	FIS_TYPE_REG_D2H	= 0x34,	// Register FIS - device to host
	FIS_TYPE_DMA_ACT	= 0x39,	// DMA activate FIS - device to host
	FIS_TYPE_DMA_SETUP	= 0x41,	// DMA setup FIS - bidirectional
	FIS_TYPE_DATA		= 0x46,	// Data FIS - bidirectional
	FIS_TYPE_BIST		= 0x58,	// BIST activate FIS - bidirectional
	FIS_TYPE_PIO_SETUP	= 0x5F,	// PIO setup FIS - device to host
	FIS_TYPE_DEV_BITS	= 0xA1,	// Set device bits FIS - device to host
};
pub const AHCIDeviceEntry = struct {
    kind: AHCIDevice,
    addr: pci.Addr
};

// FIS register - Host to Device
pub const FIS_Reg_H2D = packed struct {
    fis_type: u8,
    pmport: u4,
    _reserved_0: u3,
    c: u1,

    command: u8,
    featurel: u8,

    lba0: u8,
    lba1: u8,
    lba2: u8,
    device: u8,

    lba3: u8,
    lba4: u8,
    lba5: u8,
    featureh: u8,

    countl: u8,
    counth: u8,
    icc: u8,
    control: u8,

    _reserved_1: u64
};
// FIS register - Device to Host
pub const FIS_Reg_D2H = packed struct {
    fis_type: u8,
    pmport: u4,
    _reserved_0: u2,
    i: u1,
    _reserved_1: u1,

    status: u8,
    @"error": u8,

    lba0: u8,
    lba1: u8,
    lba2: u8,
    device: u8,

    lba3: u8,
    lba4: u8,
    lba5: u8,
    _reserved_2: u8,

    countl: u8,
    counth: u8,
    _reserved_3: u16,
    _reserved_4: u64
};

pub const FISData = packed struct {
    fis_type: u8,
};
