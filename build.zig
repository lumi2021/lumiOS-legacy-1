const std = @import("std");
const Build = std.Build;
const Target = std.Target;

pub fn build(b: *Build) void {
    b.exe_dir = "zig-out/";

    var kernel_query = Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
    };

    const Feature = std.Target.x86.Feature;
    kernel_query.cpu_features_add.addFeature(@intFromEnum(Feature.soft_float));
    kernel_query.cpu_features_sub.addFeature(@intFromEnum(Feature.mmx));
    kernel_query.cpu_features_sub.addFeature(@intFromEnum(Feature.sse));
    kernel_query.cpu_features_sub.addFeature(@intFromEnum(Feature.sse2));
    kernel_query.cpu_features_sub.addFeature(@intFromEnum(Feature.avx));
    kernel_query.cpu_features_sub.addFeature(@intFromEnum(Feature.avx2));

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const kernel = b.addExecutable(.{
        .name = "kernelx64",
        .root_source_file = b.path("src/kernel/main.zig"),
        .target = b.resolveTargetQuery(kernel_query),
        .optimize = optimize,
        .code_model = .kernel
    });

    kernel.entry = .disabled;
    kernel.setLinkerScriptPath(b.path("src/kernel/assets/linkScript.ld"));

    const install_boot_step = b.addInstallFile(b.path("src/limine/BOOTX64.EFI"), "EFI/BOOT/BOOTX64.EFI");
    const install_config_step = b.addInstallFile(b.path("src/limine/limine.conf"), "limine.conf");
    const install_kernel_step = b.addInstallArtifact(kernel, .{});

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-M", "q35",
        "-bios", "OVMF.fd",
        
        // HD, serial, video, etc
        "-hdd",  "fat:rw:zig-out",
        "-serial",  "mon:stdio",
        "-monitor",  "vc",
        "-display",  "gtk",

        // Aditional devices
        //"-usb",
        "-device", "qemu-xhci,id=usb",
        "-device", "usb-kbd",
        "-device", "usb-mouse",
        
        // Debug
        "-D", "log.txt",
        "-d", "int,cpu_reset",
        "--no-reboot",
        "--no-shutdown",
        "-s",
        //"-trace", "*xhci*",
        //"-m", "256M",
    });

    run_cmd.step.dependOn(&install_boot_step.step);
    run_cmd.step.dependOn(&install_config_step.step);
    run_cmd.step.dependOn(&install_kernel_step.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
