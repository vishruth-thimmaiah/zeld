const std = @import("std");
const elf = @import("elf");
const parser = @import("parser");
const linker = @import("linker").ElfLinker;
const writer = @import("writer");

comptime {
    _ = @import("basic.zig");
}

fn build_bin(allocator: std.mem.Allocator, file: []const u8, output: []const u8) !void {
    var command = std.process.Child.init(
        &[_][]const u8{ "gcc", "-o", output, "-xc", "-c", "-" },
        allocator,
    );

    command.stdin_behavior = .Pipe;
    try command.spawn();

    if (command.stdin) |stdin| {
        defer stdin.close();
        defer command.stdin = null;
        try stdin.writer().writeAll(file);
    }

    const result = try command.wait();
    if (result.Exited != 0) {
        return error.FailedToBuild;
    }
}

fn build_output(allocator: std.mem.Allocator, output: []const u8) !u8 {
    var build_command = std.process.Child.init(
        &[_][]const u8{ "gcc", "zig-out/tests/file3.o", "-o", output },
        allocator,
    );

    try build_command.spawn();
    _ = try build_command.wait();

    var run_command = std.process.Child.init(
        &[_][]const u8{output},
        allocator,
    );

    run_command.stdout_behavior = .Ignore;

    try run_command.spawn();
    const result = try run_command.wait();
    return result.Exited;
}

pub fn build(input_1: []const u8, input_2: []const u8) !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try build_bin(allocator, input_1, "zig-out/tests/file1.o");
    try build_bin(allocator, input_2, "zig-out/tests/file2.o");

    const file1 = try std.fs.cwd().openFile("zig-out/tests/file1.o", .{});
    defer file1.close();
    const file2 = try std.fs.cwd().openFile("zig-out/tests/file2.o", .{});
    defer file2.close();

    const elfFiles = [2]elf.Elf64{
        try parser.new(allocator, file1),
        try parser.new(allocator, file2),
    };

    defer {
        for (elfFiles) |elfObj| {
            elfObj.deinit();
        }
    }

    var elfLinker = try linker.new(allocator, &elfFiles);
    defer elfLinker.deinit();
    try elfLinker.link();

    try writer.writer(elfLinker.out, "zig-out/tests/file3.o");

    const result = try build_output(allocator, "zig-out/tests/file4.out");

    return result;
}
