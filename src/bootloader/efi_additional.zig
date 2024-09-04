//! Some additional EFI stuff
//! 2023 by Samuel Fiedler

const std = @import("std");
const uefi = std.os.uefi;
pub const efi_page_mask: usize = 0xfff;
pub const efi_page_shift: usize = 12;

/// Convert a memory size to memory pages (4096 bytes each)
pub inline fn efiSizeToPages(value: anytype) @TypeOf(value) {
    const addition: @TypeOf(value) = if (value & efi_page_mask != 0) 1 else 0;
    const ret = (value >> efi_page_shift) + addition;
    return ret;
}
