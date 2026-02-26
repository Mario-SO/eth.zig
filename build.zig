const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main library module
    const eth_module = b.addModule("eth", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/unit_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "eth", .module = eth_module },
            },
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Integration tests (requires Anvil)
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/integration_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "eth", .module = eth_module },
            },
        }),
    });

    const run_integration_tests = b.addRunArtifact(integration_tests);
    const integration_step = b.step("integration-test", "Run integration tests (requires Anvil)");
    integration_step.dependOn(&run_integration_tests.step);
}
