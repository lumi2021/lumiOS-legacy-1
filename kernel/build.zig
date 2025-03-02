const std = @import("std");
const Build = std.Build;
const Target = std.Target;
const Step = Build.Step;

pub fn build(b: *Build) void {
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

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(kernel_query),
        .optimize = optimize,
        .code_model = .kernel
    });

    kernel.root_module.red_zone = false;
    kernel.entry = .disabled;
    kernel.setLinkerScript(b.path("../deps/linking/linkScript.ld"));

    // dependences
    const oslib = b.dependency("osstd", .{}).module("osstd");
    kernel.root_module.addImport("osstd", oslib);

    // steps
    const install_kernel_step = b.addInstallArtifact(kernel, .{});
    b.getInstallStep().dependOn(&install_kernel_step.step);
}
