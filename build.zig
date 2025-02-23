const std = @import("std");
const Build = std.Build;
const Target = std.Target;

const kernel_package = @import("kernel");
const apps_package = [_][]const u8 {
    "test_program"
};

pub fn build(b: *Build) void {
    b.exe_dir = "zig-out/";

    // bootloader
    const install_bootloadr_step = b.step("install bootloader", "");
    install_bootloadr_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine_bootloaderx64.EFI"), ".disk/EFI/BOOT/BOOTX64.EFI").step);
    install_bootloadr_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine_config.txt"), ".disk/limine.conf").step);
    install_bootloadr_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine-uefi-cd.bin"), ".disk/boot/limine/limine-uefi-cd.bin").step);

    // kernel
    const kernel_dep = b.dependency("kernel", .{});
    const kernel = kernel_dep.artifact("kernel");
    const install_kernel_step = b.addInstallFile(kernel.getEmittedBin(), ".disk/kernelx64");

    // cmd commands
    const geneate_img_cmd = b.addSystemCommand(&.{
        "xorriso",
        "-as", "mkisofs",
        "-R",

        "-no-emul-boot",
        "-boot-load-size", "4",
        "-boot-info-table",
        "-efi-boot-part",
        "--efi-boot-image",
        "--protective-msdos-label",

        "--efi-boot", "boot/limine/limine-uefi-cd.bin",

        "zig-out/.disk/",
        "-o", "zig-out/lumiOS.iso",
    });
    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        
        "-M", "q35",
        "-bios", "deps/debug/OVMF.fd",
        "-m", "256M",

        // serial, video, etc

        "-serial", "mon:stdio",

        "-monitor", "vc",
        "-display", "gtk",

        // Aditional devices
        "-device", "ahci,id=ahci",
        "-device", "ide-hd,drive=hdd,bus=ahci.0",

        // Debug
        "-D", "log.txt",
        "-d", "int,cpu_reset",
        "--no-reboot",
        "--no-shutdown",
        "-s",
        //"-trace", "*xhci*",

        // Disk
        //"-hdd", "fat:rw:zig-out/.disk"
        "-drive", "id=hdd,file=zig-out/lumiOS.iso,format=raw,if=none",
    });

    geneate_img_cmd.step.dependOn(install_bootloadr_step);
    geneate_img_cmd.step.dependOn(&install_kernel_step.step);

    run_cmd.step.dependOn(&geneate_img_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the OS in qemu");
    run_step.dependOn(&run_cmd.step);
}
