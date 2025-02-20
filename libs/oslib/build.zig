const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
    });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    _ = b.addModule("oslib", .{
        .optimize = optimize,
        .target = target,

        .root_source_file = b.path("src/oslib.zig"),
        .code_model = .kernel,
    });

}
