const std = @import("std");
const Build = std.Build;
const Target = std.Target;

const kernel_build = @import("src/kernel-build.zig");

pub fn build(b: *Build) void {
    b.exe_dir = "zig-out/";

    const install_boot_deps_step = b.addInstallFile(b.path("deps/boot/limine_bootloaderx64.EFI"), "EFI/BOOT/BOOTX64.EFI");
    const install_config_deps_step = b.addInstallFile(b.path("deps/boot/limine_config.txt"), "limine.conf");

    const build_kernel_step = kernel_build.build_kernel(b);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-M",
        "q35",
        "-bios",
        "deps/debug/OVMF.fd",

        // HD, serial, video, etc
        "-hdd",
        "fat:rw:zig-out",
        "-serial",
        "mon:stdio",
        "-monitor",
        "vc",
        "-display",
        "gtk",

        // Aditional devices
        //"-usb",
        "-device",
        "qemu-xhci,id=usb",
        "-device",
        "usb-kbd",
        "-device",
        "usb-mouse",

        // Debug
        "-D",
        "log.txt",
        "-d",
        "int,cpu_reset",
        "--no-reboot",
        "--no-shutdown",
        "-s",
        //"-trace", "*xhci*",
        //"-m", "256M",
    });

    run_cmd.step.dependOn(&install_boot_deps_step.step);
    run_cmd.step.dependOn(&install_config_deps_step.step);
    run_cmd.step.dependOn(build_kernel_step);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
