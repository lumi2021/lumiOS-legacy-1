const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Target = std.Target;
const builtin = @import("builtin");

// imageBuilder dependences references
const imageBuilder = @import("deps/imageBuilder/image-builder/main.zig");
const MiB = imageBuilder.size_constants.MiB;
const GPTr = imageBuilder.size_constants.GPT_reserved_sectors;

const kernel_package = @import("kernel");
const apps_package = [_][]const u8 {
    "test_program"
};

pub fn build(b: *Build) void {
    b.exe_dir = "zig-out/";

    // bootloader
    var install_bootloader_step = addDummyStep(b, "Install Bootloader");
    {
        install_bootloader_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine_bootloaderx64.EFI"),
            ".disk/EFI/BOOT/BOOTX64.EFI").step);
        install_bootloader_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine_config.txt"),
            ".disk/boot/limine/limine.conf").step);
        //install_bootloader_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine-uefi-cd.bin"),
        //    ".disk/boot/limine/limine-uefi-cd.bin").step);
        //install_bootloader_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine-bios-cd.bin"),
        //    ".disk/boot/limine/limine-bios-cd.bin").step);
        install_bootloader_step.dependOn(&b.addInstallFile(b.path("deps/boot/limine-bios.sys"),
            ".disk/boot/limine/limine-bios.sys").step);
    }

    // kernel
    const kernel_dep = b.dependency("kernel", .{});
    const kernel = kernel_dep.artifact("kernel");
    const install_kernel_step = b.addInstallFile(kernel.getEmittedBin(), ".disk/kernelx64");

    // random files for dbg
    var buf: [18]u8 = undefined;
    for (0 .. 5) |i| {
        const a = b.addInstallFile(b.path(".zigversion"),
        std.fmt.bufPrint(&buf, ".disk/FILE{:0>4}.TXT", .{i}) catch unreachable);
        install_kernel_step.step.dependOn(&a.step);
    }

    // generate disk image
    var disk = imageBuilder.addBuildGPTDiskImage(b, 20*MiB + GPTr, "lumiOS.img");
    disk.addPartition(.vFAT, "Main", "zig-out/.disk", 15*MiB);

    disk.step.dependOn(install_bootloader_step);
    disk.step.dependOn(&install_kernel_step.step);

    // cmd commands
    const limine_bios_install = b.addSystemCommand(&.{
        "deps/boot/" ++ (if (builtin.os.tag == .windows) "limine.exe" else "limine"),
        "bios-install",
        "zig-out/lumiOS.img"
    });
    const run_qemu = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        
        "-M", "q35",
        "-bios", "deps/debug/OVMF.fd", // for UEFI emulation (not recommended)
        "-m", "512M",
        "-vga", "virtio",

        "-accel",
        if (builtin.os.tag == .linux) "kvm"
        else "whpx",

        // serial, video, etc
        "-serial", "file:serial.txt",
        "-monitor", "mon:stdio",
        "-display", "gtk,zoom-to-fit=on",

        // Aditional devices
        "-device", "ahci,id=ahci",
        "-device", "ide-hd,drive=drive0,bus=ahci.0",

        //"-usb",
        //"-device", "qemu-xhci,id=usb",
        //"-device", "usb-mouse",
        //"-device", "usb-kbd",

        // Debug
        "-D", "log.txt",
        //"-d", "int,cpu_reset",
        //"--no-reboot",
        //"--no-shutdown",
        //"-trace", "*xhci*",

        // Disk
        "-drive", "id=drive0,file=zig-out/lumiOS.img,format=raw,if=none",
    });

    limine_bios_install.step.dependOn(&disk.step);

    // default (only build)
    b.getInstallStep().dependOn(&limine_bios_install.step);

    run_qemu.step.dependOn(b.getInstallStep());

    // build and run
    const run_step = b.step("run", "Run the OS in qemu");
    run_step.dependOn(&run_qemu.step);
}

fn addDummyStep(b: *Build, name: []const u8) *Step {
    const step = b.allocator.create(Step) catch unreachable;
    step.* = Step.init(.{
        .id = .custom,
        .name = name,
        .owner = b
    });
    return step;
}
