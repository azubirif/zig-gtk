const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gtk_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gtk_module.linkSystemLibrary("gtk4", .{});

    const exe = b.addExecutable(.{
        .name = "zig-gtk-demo",
        .root_module = gtk_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the GTK demo");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .name = "unit-tests",
        .root_module = gtk_module,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const file_browser_module = b.createModule(.{
        .root_source_file = b.path("src/core/file_browser.zig"),
        .target = target,
        .optimize = optimize,
    });
    const file_browser_tests = b.addTest(.{
        .name = "file-browser-tests",
        .root_module = file_browser_module,
    });
    const run_file_browser_tests = b.addRunArtifact(file_browser_tests);
    test_step.dependOn(&run_file_browser_tests.step);
}
