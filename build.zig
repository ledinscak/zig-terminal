const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const terminal_mod = b.addModule("terminal", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Examples
    const examples_step = b.step("examples", "Build all examples");
    for ([_][]const u8{ "colors", "cursor", "scroll", "styles" }) |name| {
        addExample(b, examples_step, terminal_mod, target, optimize, name);
    }

    // Tests
    const test_step = b.step("test", "Run unit tests");
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // Format check
    const check_step = b.step("check", "Check formatting");
    check_step.dependOn(&b.addFmt(.{ .paths = &.{ "src", "examples", "build.zig" } }).step);

    // Clean
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    terminal_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
) void {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "terminal", .module = terminal_mod }},
        }),
    });

    const install = b.addInstallArtifact(exe, .{});
    examples_step.dependOn(&install.step);

    const run_step = b.step(b.fmt("run-{s}", .{name}), b.fmt("Run the {s} example", .{name}));
    run_step.dependOn(&b.addRunArtifact(exe).step);
}
