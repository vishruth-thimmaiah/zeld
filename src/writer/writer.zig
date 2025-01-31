const std = @import("std");
const parser = @import("parser");
const writeHeader = @import("header.zig").writeHeader;
const writeSHeader = @import("sheader.zig").writeSHeader;
const writeSections = @import("sections.zig").writeSections;

pub fn writer(elf: parser.Elf64, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{ .mode = 0o777 });
    defer file.close();

    const sectionHeaders = try writeSHeader(elf.allocator, elf.sheaders);
    defer elf.allocator.free(sectionHeaders);

    const sections = try writeSections(elf.allocator, elf.sections);
    defer elf.allocator.free(sections);

    try file.writeAll(&(try writeHeader(elf.header)));
    try file.writeAll(sections);
    try file.writeAll(sectionHeaders);
}
