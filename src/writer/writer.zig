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

    const aligned_shrd = getAlignment(elf_.header.shoff, 16) - elf_.header.shoff;
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

pub fn getAlignment(size: u64, alignment: u64) u64 {
    if (trailingZeros(size) == trailingZeros(alignment)) {
        return size;
    }
    if (alignment == 0 or alignment == 1) {
        return size;
    }
    return (size & (~alignment + 1)) + alignment;
}

pub fn trailingZeros(input: u64) u64 {
    const value: u64 = input & -%input;
    var count: u64 = 64;

    if (value != 0) count -%= 1;
    if ((value & 0xFFFFFFFF) != 0) count -%= 32;
    if ((value & 0x0000FFFF) != 0) count -%= 16;
    if ((value & 0x00FF00FF) != 0) count -%= 8;
    if ((value & 0x0F0F0F0F) != 0) count -%= 4;
    if ((value & 0x33333333) != 0) count -%= 2;
    if ((value & 0x55555555) != 0) count -%= 1;
    return count;
}
