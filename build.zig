const std = @import("std");
const Build = std.Build;
const Target = std.Target;

pub fn build(b: *Build) void {
    b.exe_dir = "zig-out/";

    const bootloader_query = Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
        .abi = .msvc,
        .ofmt = .coff,
    };
    const kernel_query = Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
    };

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const bootloader = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = b.path("src/bootloader/main.zig"),
        .target = b.resolveTargetQuery(bootloader_query),
        .optimize = optimize,
    });
    const kernel = b.addExecutable(.{
        .name = "kernelx64",
        .root_source_file = b.path("src/kernel/main.zig"),
        .target = b.resolveTargetQuery(kernel_query),
        .optimize = optimize,
    });

    kernel.entry = .disabled;
    kernel.setLinkerScriptPath(b.path("src/kernel/assets/linkScript.ld"));

    const install_boot_step = b.addInstallArtifact(bootloader, .{ .dest_dir = .{ .override = .{ .custom = "/EFI/BOOT/"} } });
    const install_kernel_step = b.addInstallArtifact(kernel, .{});

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-bios",  "OVMF.fd",
        "-D",  "log.txt",
        "-hdd",  "fat:rw:zig-out",
        "-serial",  "mon:stdio",
        "-monitor",  "vc",
        "-display",  "gtk",
        "-D", "log.txt",
        "-d", "int,cpu_reset",
        "-s",
        //"-m", "256M",
        "--no-reboot",
        "--no-shutdown",
    });

    run_cmd.step.dependOn(&install_boot_step.step);
    run_cmd.step.dependOn(&install_kernel_step.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
