const std = @import("std");
const Build = std.Build;
const Target = std.Target;
const builtin = @import("builtin");

const kernel_package = @import("kernel");
const apps_package = [_][]const u8 {
    "test_program"
};

pub fn build(b: *Build) void {
    b.exe_dir = "zig-out/";

    // bootloader
    const install_bootloadr_step = b.step("install bootloader", "");
    install_bootloadr_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine_bootloaderx64.EFI"), ".disk/EFI/BOOT/BOOTX64.EFI").step);
    install_bootloadr_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine_config.txt"), ".disk/boot/limine/limine.conf").step);
    install_bootloadr_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine-uefi-cd.bin"), ".disk/boot/limine/limine-uefi-cd.bin").step);
    install_bootloadr_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine-bios-cd.bin"), ".disk/boot/limine/limine-bios-cd.bin").step);
    install_bootloadr_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine-bios.sys"), ".disk/boot/limine/limine-bios.sys").step);

    // kernel
    const kernel_dep = b.dependency("kernel", .{});
    const kernel = kernel_dep.artifact("kernel");
    const install_kernel_step = b.addInstallFile(kernel.getEmittedBin(), ".disk/kernelx64");

    // cmd commands
    const geneate_img_cmd = b.addSystemCommand(&.{
        "xorriso",
        "-as", "mkisofs",
        "-R", "-r", "-J",

        "-b", "boot/limine/limine-bios-cd.bin",
        
        "-no-emul-boot",
        "-boot-load-size", "4",
        "-boot-info-table",
        "-hfsplus",
        "-apm-block-size", "2048",

        "--efi-boot", "boot/limine/limine-uefi-cd.bin",

        "-efi-boot-part",
        "--efi-boot-image",
        "--protective-msdos-label",

        "zig-out/.disk/",
        "-o", "zig-out/lumiOS.iso",
    });
    const limine_bios_install = b.addSystemCommand(&.{
        "deps/boot/" ++ (if (builtin.os.tag == .windows) "limine.exe" else "limine"),
        "bios-install",
        "zig-out/lumiOS.iso"
    });
    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        
        "-M", "q35",
        //"-bios", "deps/debug/OVMF.fd", // for UEFI emulation (not recommended)
        "-m", "512M",
        //"-enable-kvm",

        // serial, video, etc
        "-serial", "file:serial.txt",
        "-monitor", "mon:stdio",
        "-display", "gtk,zoom-to-fit=on",

        // Aditional devices
        "-device", "ahci,id=ahci",
        "-device", "ide-hd,drive=drive0,bus=ahci.0",

        "-device", "qemu-xhci,id=usb",
        //"-device", "usb-mouse",

        // Debug
        "-D", "log.txt",
        "-d", "int,cpu_reset",
        //"--no-reboot",
        //"--no-shutdown",
        //"-trace", "*xhci*",

        // Disk
        "-drive", "id=drive0,file=zig-out/lumiOS.iso,format=raw,if=none",
        "-boot", "order=c"
    });

    geneate_img_cmd.step.dependOn(install_bootloadr_step);
    geneate_img_cmd.step.dependOn(&install_kernel_step.step);

    limine_bios_install.step.dependOn(&geneate_img_cmd.step);
    // default (only build)
    b.getInstallStep().dependOn(&limine_bios_install.step);

    run_cmd.step.dependOn(b.getInstallStep());

    // build and run
    const run_step = b.step("run", "Run the OS in qemu");
    run_step.dependOn(&run_cmd.step);
}
