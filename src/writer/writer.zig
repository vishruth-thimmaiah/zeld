const std = @import("std");
const elf = @import("elf");
const writeHeader = @import("header.zig").writeHeader;
const writeSHeader = @import("sheader.zig").writeSHeader;
const writeSections = @import("sections.zig").writeSections;
const writePHeader = @import("pheader.zig").writePHeader;

pub fn writer(elf_: elf.Elf64, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{ .mode = 0o777 });
    defer file.close();

    var pheaders: ?[]u8 = null;
    defer elf_.allocator.free(pheaders.?);
    if (elf_.pheaders) |ph| {
        pheaders = try writePHeader(elf_.allocator, ph);
    }

    const sectionHeaders = try writeSHeader(elf_.allocator, elf_.sheaders);
    defer elf_.allocator.free(sectionHeaders);

    const sections = try writeSections(elf_.allocator, elf_.sections);
    defer elf_.allocator.free(sections);

    try file.writeAll(&(try writeHeader(elf_.header)));
    if (pheaders) |ph| try file.writeAll(ph);
    try file.writeAll(sections);
    try file.writeAll(sectionHeaders);
}
