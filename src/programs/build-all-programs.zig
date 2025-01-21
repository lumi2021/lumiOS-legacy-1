const std = @import("std");
const Build = std.Build;
const Target = std.Target;
const Step = Build.Step;

pub fn build(b: *Build) *Step {

    build_terminal(b);

    return b.step("Build all", "Build all programs");

}

fn build_terminal(b: *Build) void {

    _ = b;

}
