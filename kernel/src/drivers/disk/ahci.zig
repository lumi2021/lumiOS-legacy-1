const std = @import("std");
const os = @import("root").os;
const pci = os.drivers.pci;

const write = os.console_write("aHCI");
const st = os.stack_tracer;

const HBA_PxCMD_ST   = 0x0001;
const HBA_PxCMD_FRE  = 0x0010;
const HBA_PxCMD_FR   = 0x4000;
const HBA_PxCMD_CR   = 0x8000;

pub fn init_device(addr: pci.Addr) void {
    st.push(@src()); defer st.pop();

    const abar_addr = addr.barinfo(5).phy;
    const abar = os.memory.ptr_from_paddr(*HBARegisters, abar_addr);

    probe_port(abar);

}

fn probe_port(abar: *HBARegisters) void {
    st.push(@src()); defer st.pop();

    // Search disk in implemented ports
    const pi = abar.pi;
    
    for (0 .. 32) |i| {
        if (pi & 1 != 0) {

            const dt = check_type(&abar.ports[i]);
            if (dt == .sata) write.dbg("SATA found on port {}", .{i})
            else if (dt == .satapi) write.dbg("SATAPI found on port {}", .{i})
            else if (dt == .semb) write.dbg("SEMB found on port {}", .{i})
            else if (dt == .pm) write.dbg("PM found on port {}", .{i});
            //else write.dbg("No drive found on port {}", .{i});

        }
    }
}

fn check_type(port: *HBAPort) AHCIDevice {
    st.push(@src()); defer st.pop();

    const ssts = port.ssts;
    const ipm = (ssts >> 8) & 0x0F;
    const det = ssts & 0x0F;

    if (det != 3) return ._null;
    if (ipm != 1) return ._null;

    return switch (port.sig) {
        0xEB140101 => .satapi,
        0xC33C0101 => .semb,
        0x96690101 => .pm,
        else => .sata
    };
}

inline fn start_cmd(port: *HBAPort) void {
    st.push(@src()); defer st.pop();

    // Wait until CR (bit15) is cleared
    while (port.cmd & HBA_PxCMD_CR) {}
    // Set FRE (bit4) and ST (bit0)
    port.cmd |= HBA_PxCMD_FRE;
    port.cmd |= HBA_PxCMD_ST;
}
inline fn stop_cmd(port: *HBAPort) void {
    // Clear ST (bit0) and FRE (bit4)
    port.cmd &= ~@as(u32, HBA_PxCMD_ST);
    port.cmd &= ~@as(u32, HBA_PxCMD_FRE);

    // Wait until FR (bit14), CR (bit15) are cleared
    while ((port.cmd & HBA_PxCMD_FR) == 0 or (port.cmd & HBA_PxCMD_CR) == 0) {}
}

pub const HBARegisters = extern struct {
    cap: u32,
    ghc: u32,
    is: u32,
    pi: u32,
    vs: u32,
    ccc_ctl: u32,
    ccc_pts: u32,
    em_loc: u32,
    em_ctl: u32,
    cap2: u32,
    bohc: u32,
    _reserved_0: [0xA0 - 0x2C]u8,
    vendor: [0x100 - 0xA0]u8,

    ports: [32]HBAPort,
};

const HBAPort = extern struct {
    clb: u32, clbu: u32,
    fb: u32, fbu: u32,
    is: u32,
    ie: u32,
    cmd: u32,
    _reserved_0: u32,
    tfd: u32,
    sig: u32,
    ssts: u32,
    sctl: u32,
    serr: u32,
    sact: u32,
    ci: u32,
    sntf: u32,
    fbs: u32,
    _reserved_1: [11]u32,
    vendor: [4]u32,
};

const AHCIDevice = enum {
    _null,
    sata,
    semb,
    pm,
    satapi
};
