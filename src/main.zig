const std = @import("std");

const parser = @import("parser");
const linker = @import("linker").ElfLinker;
const writer = @import("writer");
const Args = @import("args.zig").Args;

const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = Args.parse(allocator) catch |err| {
        print("Error {s}: Failed to parse args\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer args.deinit();

    var elfFiles = std.ArrayList(parser.Elf64).init(allocator);
    defer {
        for (elfFiles.items) |elfObj| {
            elfObj.deinit();
        }
        elfFiles.deinit();
    }

    for (args.inputs) |arg| {
        const file = std.fs.cwd().openFile(arg, .{}) catch |err| {
            std.debug.print("Error {s}: Failed to open '{s}'\n", .{ @errorName(err), arg });
            std.process.exit(1);
        };
        defer file.close();

        const elfObj = try parser.Elf64.new(allocator, file);
        try elfFiles.append(elfObj);
    }

    var elfLinker = try linker.new(allocator, elfFiles.items);
    defer elfLinker.deinit();
    try elfLinker.link();

    try writer.writer(elfLinker.out, args.output);
}
