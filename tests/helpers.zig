const std = @import("std");
const parser = @import("parser");
const linker = @import("linker").ElfLinker;
const writer = @import("writer");

fn build_bin(allocator: std.mem.Allocator, file: []const u8, output: []const u8) !void {
    var command = std.process.Child.init(
        &[_][]const u8{ "gcc", "-xc", "-c", "-", "-o", output },
        allocator,
    );

    command.stdin_behavior = .Pipe;
    try command.spawn();

    if (command.stdin) |stdin| {
        defer stdin.close();
        defer command.stdin = null;
        try stdin.writer().writeAll(file);
    }

    _ = try command.wait();
}

fn build_output(allocator: std.mem.Allocator, output: []const u8) !u8 {
    var build_command = std.process.Child.init(
        &[_][]const u8{ "gcc", "zig-out/file3.o", "-o", output },
        allocator,
    );

    try build_command.spawn();
    _ = try build_command.wait();

    var run_command = std.process.Child.init(
        &[_][]const u8{ output },
        allocator,
    );

    try run_command.spawn();
    const result = try run_command.wait();
    return result.Exited;
}

pub fn build(input_1: []const u8, input_2: []const u8) !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try build_bin(allocator, input_1, "zig-out/file1.o");
    try build_bin(allocator, input_2, "zig-out/file2.o");

    const file1 = try std.fs.cwd().openFile("zig-out/file1.o", .{});
    defer file1.close();
    const file2 = try std.fs.cwd().openFile("zig-out/file2.o", .{});
    defer file2.close();

    const elfFiles = [2]parser.Elf64{
        try parser.Elf64.new(allocator, file1),
        try parser.Elf64.new(allocator, file2),
    };

    defer {
        for (elfFiles) |elfObj| {
            elfObj.deinit();
        }
    }

    var elfLinker = try linker.new(allocator, &elfFiles);
    defer elfLinker.deinit();
    try elfLinker.link();

    try writer.writer(elfLinker.out, "zig-out/file3.o");

    const result = try build_output(allocator, "zig-out/file4.out");

    return result;
}
