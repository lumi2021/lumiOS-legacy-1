const std = @import("std");
const Build = std.Build;
const Target = std.Target;
const Step = Build.Step;

// programs
const test_prg = @import("programs/test/build.zig").build;

pub fn build_all(b: *Build) *Step {

    const step = b.step("Build all", "Build all programs");

    const test_prg_step = test_prg(b);
    step.dependOn(test_prg_step);

    return step;

}

