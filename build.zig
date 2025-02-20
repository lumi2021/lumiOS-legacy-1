const std = @import("std");
const Build = std.Build;
const Target = std.Target;
const disk_image = @import("disk_image_step");

const kernel_package = @import("kernel");
const apps_package = [_][]const u8 {
    "test_program"
};

pub fn build(b: *Build) void {
    b.exe_dir = "zig-out/";

    var image = disk_image.FileSystemBuilder.init(b);

    // bootloader
    image.addFile(b.path("deps/boot/limine_bootloaderx64.EFI"), "EFI/BOOT/BOOTX64.EFI");
    image.addFile(b.path("deps/boot/limine_config.txt"), "limine.conf");

    // kernel
    const kernel_dep = b.dependency("kernel", .{});
    const kernel = kernel_dep.artifact("kernel");
    image.addFile(kernel.getEmittedBin(), "/kernelx64");

    // bake disk image
    const image_finalize = image.finalize(.{ .format = .fat16, .label = "lumiOS" });
    const disk = disk_image.initializeDisk(b.dependency("disk_image_step", .{}), 0x100_0000,
        .{ .mbr = .{
            .partitions = .{
                &.{
                    .size = 0x90_0000,
                    .offset = 0x8000,
                    .bootable = true,
                    .type = .fat16_lba,
                    .data = .{ .fs = image_finalize }
                },
                null,
                null,
                null
            }
        }},
    );
    const install_disk = b.addInstallFile(disk.getImageFile(), "disk.img");

    // cmd command
    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-M",
        "q35",
        "-bios",
        "deps/debug/OVMF.fd",

        // serial, video, etc

        "-serial",
        "mon:stdio",

        "-monitor",
        "vc",
        "-display",
        "gtk",

        // Aditional devices


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

        // Image
        "zig-out/disk.img",
    });

    run_cmd.step.dependOn(&install_disk.step);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the OS in qemu");
    run_step.dependOn(&run_cmd.step);
}
