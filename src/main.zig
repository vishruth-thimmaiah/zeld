const std = @import("std");
const parser = @import("parser.zig");

const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var argsIter = std.process.argsWithAllocator(allocator) catch |err| {
        print("Failed to get args: {s}\n", .{@errorName(err)});
        return;
    };
    defer argsIter.deinit();

    _ = argsIter.next();

    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();
    while (argsIter.next()) |arg| {
        try args.append(arg);
    }

    if (args.items.len == 0) {
        print("No files specified\n", .{});
        return;
    }

    for (args.items) |arg| {
        const file = try std.fs.cwd().openFile(arg, .{});
        defer file.close();
        _ = try parser.Elf64.new(allocator, file);
    }
}
