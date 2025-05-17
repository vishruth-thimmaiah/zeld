const std = @import("std");
const elf = @import("elf");
const writeHeader = @import("header.zig").writeHeader;
const writeSHeader = @import("sheader.zig").writeSHeader;
const writeSections = @import("sections.zig").writeSections;
const writePHeader = @import("pheader.zig").writePHeader;

pub fn writer(elf_: *elf.Elf64, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{ .mode = 0o777 });
    defer file.close();

    var pheaders: ?[]u8 = null;
    defer if (pheaders) |ph| elf_.allocator.free(ph);
    if (elf_.pheaders) |ph| {
        pheaders = try writePHeader(elf_.allocator, ph);
    }

    const sectionHeaders = try writeSHeader(elf_.allocator, elf_.sheaders);
    defer elf_.allocator.free(sectionHeaders);

    const sections = try writeSections(elf_.allocator, elf_.sections);
    defer elf_.allocator.free(sections);

    const aligned_shrd = elf.helpers.getAlignment(elf_.header.shoff, 16) - elf_.header.shoff;
    elf_.header.shoff += aligned_shrd;

    try file.writeAll(&(try writeHeader(elf_.header)));
    if (pheaders) |ph| try file.writeAll(ph);
    try file.writeAll(sections);
    if (aligned_shrd != 0) {
        const zeros = try elf_.allocator.alloc(u8, aligned_shrd);
        defer elf_.allocator.free(zeros);
        @memset(zeros, 0);
        try file.writeAll(zeros);
    }
    try file.writeAll(sectionHeaders);
}
