const std = @import("std");
const parser = @import("parser");
const writeHeader = @import("header.zig").writeHeader;

pub fn writer(elf: parser.Elf64, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{ .mode = 0o777 });
    defer file.close();

    try file.writeAll(&(try writeHeader(elf.header)));
}
