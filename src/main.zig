const std = @import("std");

const elf = @import("elf");
const parser = @import("parser");
const ElfLinker = @import("linker").ElfLinker;
const writer = @import("writer");
const Args = @import("args.zig").Args;
const errors = @import("errors.zig");

const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = Args.parse(allocator) catch |err| errors.handleError(err);
    defer args.deinit();

    const start_file = try parser.new(allocator, &args.rel_inputs[0]);
    defer start_file.deinit();
    var linker = try ElfLinker.new(allocator, &start_file, args.linker_args);
    defer linker.deinit();

    // TODO: Free the memory of the elfObjects immediately after each merge
    var elfObjects = try allocator.alloc(elf.Elf64, args.rel_inputs.len - 1);
    defer allocator.free(elfObjects);
    defer {
        for (elfObjects) |obj| obj.deinit();
    }

    for (args.rel_inputs[1..], 0..) |*path, i| {
        const elfObj = try parser.new(allocator, path);
        elfObjects[i] = elfObj;
        try linker.merge(&elfObj);
    }

    try linker.link();

    try writer.writer(&linker.out, args.output);
}
