const std = @import("std");
const elf = @import("elf");
const writeHeader = @import("header.zig").writeHeader;
const writeSHeader = @import("sheader.zig").writeSHeader;
const writeSections = @import("sections.zig").writeSections;

pub fn writer(elf_: elf.Elf64, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{ .mode = 0o777 });
    defer file.close();

    const sectionHeaders = try writeSHeader(elf_.allocator, elf_.sheaders);
    defer elf_.allocator.free(sectionHeaders);

    const sections = try writeSections(elf_.allocator, elf_.sections);
    defer elf_.allocator.free(sections);

    try file.writeAll(&(try writeHeader(elf_.header)));
    try file.writeAll(sections);
    try file.writeAll(sectionHeaders);
}
