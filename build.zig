const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library module (for use as dependency)
    const terminal_mod = b.addModule("terminal", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Examples
    const examples = [_][]const u8{ "colors", "cursor", "scroll", "styles" };
    const examples_step = b.step("examples", "Build all examples");

    for (examples) |name| {
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

        // Individual run step for each example
        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step(
            b.fmt("run-{s}", .{name}),
            b.fmt("Run the {s} example", .{name}),
        );
        run_step.dependOn(&run_cmd.step);
    }

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Clean
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
}
