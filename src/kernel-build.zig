const std = @import("std");
const Build = std.Build;
const Target = std.Target;
const Step = Build.Step;

const programs = @import("programs/build-all-programs.zig");

pub fn build_kernel(b: *Build) *Step {
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

    kernel.root_module.red_zone = false;
    kernel.entry = .disabled;
    kernel.setLinkerScriptPath(b.path("deps/linking/linkScript.ld"));

    // dependences
    const oslib = b.addModule("oslib", .{
        .root_source_file = b.path("src/oslib/oslib.zig")
    });
    kernel.root_module.addImport("oslib", oslib);

    // steps
    const programs_step = programs.build(b);
    const install_kernel_step = b.addInstallArtifact(kernel, .{});

    var kernel_build_step = b.step("Build kernel",
    "Build the kernel");

    kernel_build_step.dependOn(&install_kernel_step.step);
    kernel_build_step.dependOn(programs_step);

    return kernel_build_step;
}
