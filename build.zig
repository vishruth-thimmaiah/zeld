const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const elf = b.addModule("elf", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .cwd_relative = "src/elf/elf.zig" },
    });

    const parser = b.addModule("parser", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .cwd_relative = "src/parser/elf.zig" },
    });
    parser.addImport("elf", elf);

    const linker = b.addModule("linker", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .cwd_relative = "src/linking/linker.zig" },
    });
    linker.addImport("elf", elf);

    const writer = b.addModule("writer", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .cwd_relative = "src/writer/writer.zig" },
    });
    writer.addImport("elf", elf);

    const exe = b.addExecutable(.{
        .name = "zeld",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("parser", parser);
    exe.root_module.addImport("linker", linker);
    exe.root_module.addImport("writer", writer);
    exe.root_module.addImport("elf", elf);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".   
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("tests/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.root_module.addImport("parser", parser);
    exe_unit_tests.root_module.addImport("linker", linker);
    exe_unit_tests.root_module.addImport("writer", writer);
    exe_unit_tests.root_module.addImport("elf", elf);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const create_tests_dir = b.addSystemCommand(&[_][]const u8{ "mkdir", "-p", "zig-out/tests" });
    const cleanup_tests = b.addRemoveDirTree("zig-out/tests");

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    cleanup_tests.step.dependOn(&run_exe_unit_tests.step);
    run_exe_unit_tests.step.dependOn(&create_tests_dir.step);
    test_step.dependOn(&cleanup_tests.step);

    //fmt
    const fmt_action = b.addFmt(.{ .paths = &.{ "src", "tests" } });
    const fmt_step = b.step("fmt", "Run the fmt tool on all source files");
    fmt_step.dependOn(&fmt_action.step);
}
