const std = @import("std");
const Build = std.Build;
const Target = std.Target;
const Step = Build.Step;

pub fn build(b: *Build) *Step {

    const target = Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .linux
    };
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "test_prg",
        .root_source_file = b.path("src/programs/test/src/main.zig"),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize
    });

    const install_step = b.addInstallArtifact(exe, .{});

    return &install_step.step;

}
