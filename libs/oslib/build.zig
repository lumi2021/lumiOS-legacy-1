const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {

    var target_query = std.Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
    };

    const Feature = std.Target.x86.Feature;
    target_query.cpu_features_add.addFeature(@intFromEnum(Feature.soft_float));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.mmx));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.sse));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.sse2));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.avx));
    target_query.cpu_features_sub.addFeature(@intFromEnum(Feature.avx2));

    const target = b.resolveTargetQuery(target_query);
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });


    _ = b.addModule("oslib", .{
        .optimize = optimize,
        .target = target,

        .root_source_file = b.path("src/oslib.zig"),
        .code_model = .kernel,
    });

}
