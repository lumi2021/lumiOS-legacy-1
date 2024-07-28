const std = @import("std");

pub fn build(b: *std.Build) void {

    b.exe_dir = "zig-out/";
    
    const boot_target = b.standardTargetOptions(.{
        .default_target = .{
            .os_tag = .uefi,
            .cpu_arch = .x86_64,
            .abi = .gnu,
        },
    });
    const kernel_target = getKernelTarget(b, .x86_64);
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const boot = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = b.path("src/boot_main.zig"),
        .target = boot_target,
        .optimize = optimize
    });
    
    const kernel = b.addExecutable(.{
        .name = "kernelx64",
        .target = kernel_target,
        .optimize = optimize,
        .code_model = .kernel,
        .root_source_file = b.path("src/kernel_main.zig")
    });

    kernel.setLinkerScript(b.path("./linkerScript.ld"));

    const install_boot_step = b.addInstallArtifact(boot,
    .{.dest_dir = .{ .override = .{ .custom = "EFI/BOOT/" } }});

    const install_kernel_step = b.addInstallArtifact(kernel, .{});

    b.getInstallStep().dependOn(&install_boot_step.step);
    b.getInstallStep().dependOn(&install_kernel_step.step);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-serial", "stdio",
        "-bios", "OVMF.fd",
        //"-s", "-S",
        "-drive", "format=raw,file=fat:rw:zig-out" });
    
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

}

fn getKernelTarget(b: *std.Build, arch: std.Target.Cpu.Arch) std.Build.ResolvedTarget {
    const query: std.Target.Query = .{
        .cpu_arch = arch,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_add = switch (arch) {
            .x86_64 => std.Target.x86.featureSet(&.{.soft_float}),
            else => @panic("unsupported architecture"),
        },
        .cpu_features_sub = switch (arch) {
            .x86_64 => std.Target.x86.featureSet(&.{ .mmx, .sse, .sse2, .avx, .avx2 }),
            else => @panic("unsupported architecture"),
        },
    };

    return b.resolveTargetQuery(query);
}
