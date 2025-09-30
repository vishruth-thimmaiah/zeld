const std = @import("std");
const elf = @import("elf");
const parser = @import("parser");
const linker = @import("linker").ElfLinker;
const writer = @import("writer");

comptime {
    _ = @import("asm_exec.zig");
    _ = @import("c_rela.zig");
    _ = @import("clib.zig");
}

fn build_object(allocator: std.mem.Allocator, file: []const u8, output: []const u8, lang: []const u8) !void {
    var command = std.process.Child.init(
        &[_][]const u8{ "gcc", "-o", output, lang, "-c", "-" },
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

fn build_output_for_rela(allocator: std.mem.Allocator, output: []const u8) !u8 {
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

pub fn build_rela(input_1: []const u8, input_2: []const u8) !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try build_object(allocator, input_1, "zig-out/tests/file1.o", "-xc");
    try build_object(allocator, input_2, "zig-out/tests/file2.o", "-xc");

    var file1: []const u8 = &"zig-out/tests/file1.o".*;
    var file2: []const u8 = &"zig-out/tests/file2.o".*;

    const elfFiles = [2]elf.Elf64{
        try parser.new(allocator, &file1),
        try parser.new(allocator, &file2),
    };

    defer {
        for (elfFiles) |elfObj| {
            elfObj.deinit();
        }
    }

    var elfLinker = try linker.new(allocator, &elfFiles[0], .{
        .output_type = .ET_REL,
        .dynamic_linker = null,
        .shared_libs = undefined,
    });
    defer elfLinker.deinit();
    try elfLinker.merge(&elfFiles[1]);
    try elfLinker.link();

    try writer.writer(&elfLinker.out, "zig-out/tests/file3.o");

    const result = try build_output_for_rela(allocator, "zig-out/tests/file4.out");

    return result;
}

pub fn build_exec(input: []const u8) !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try build_object(allocator, input, "zig-out/tests/file1.o", "-xassembler");

    var file: []const u8 = &"zig-out/tests/file1.o".*;
    const elfFile = try parser.new(allocator, &file);
    defer elfFile.deinit();

    var elfLinker = try linker.new(allocator, &elfFile, .{
        .output_type = .ET_EXEC,
        .dynamic_linker = null,
        .shared_libs = undefined,
    });
    defer elfLinker.deinit();
    try elfLinker.link();

    try writer.writer(&elfLinker.out, "zig-out/tests/file2.out");

    var run_command = std.process.Child.init(
        &[_][]const u8{"zig-out/tests/file2.out"},
        allocator,
    );

    run_command.stdout_behavior = .Pipe;

    try run_command.spawn();
    const result = try run_command.wait();
    if (result == .Signal) {
        std.log.warn("Failed to run with signal: {d}", .{result.Signal});
        return error.FailedToRun;
    }
    return result.Exited;
}

pub fn build_clib_exec(input: []const u8) !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try build_object(allocator, input, "zig-out/tests/file1.o", "-xc");

    var file: []const u8 = &"zig-out/tests/file1.o".*;
    var crt_path: []const u8 = try get_clib_exec(allocator, "crt1.o");
    defer allocator.free(crt_path);
    const elfFile = try parser.new(allocator, &file);
    defer elfFile.deinit();
    const crt_file = try parser.new(allocator, &crt_path);
    defer crt_file.deinit();

    const shared_libs: []const []const u8 = &[_][]const u8{try get_clib_exec(allocator, "libc.so.6")};
    defer allocator.free(shared_libs[0]);

    const dynamic_linker = try get_clib_exec(allocator, "ld-linux-x86-64.so.2");
    defer allocator.free(dynamic_linker);

    var elfLinker = try linker.new(allocator, &elfFile, .{
        .output_type = .ET_EXEC,
        .dynamic_linker = dynamic_linker,
        .shared_libs = @constCast(shared_libs),
    });
    try elfLinker.merge(&crt_file);
    defer elfLinker.deinit();
    try elfLinker.link();

    try writer.writer(&elfLinker.out, "zig-out/tests/file2.out");

    var run_command = std.process.Child.init(
        &[_][]const u8{"zig-out/tests/file2.out"},
        allocator,
    );

    run_command.stdout_behavior = .Pipe;

    try run_command.spawn();
    const result = try run_command.wait();
    if (result == .Signal) {
        std.log.warn("Failed to run with signal: {d}", .{result.Signal});
        return error.FailedToRun;
    }
    return result.Exited;
}

fn get_clib_exec(allocator: std.mem.Allocator, file: []const u8) ![]u8 {
    var command = std.process.Child.init(
        &[_][]const u8{ "gcc", "--print-file-name", file },
        allocator,
    );

    command.stdout_behavior = .Pipe;

    try command.spawn();
    const path = (try command.stdout.?.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', 100)).?;
    defer allocator.free(path);

    return std.fs.realpathAlloc(allocator, path);
}
