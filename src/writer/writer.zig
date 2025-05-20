const std = @import("std");
const elf = @import("elf");
const writeHeader = @import("header.zig").writeHeader;
const writeSHeader = @import("sheader.zig").writeSHeader;
const writeSections = @import("sections.zig").writeSections;
const writePHeader = @import("pheader.zig").writePHeader;

pub fn writer(elf_: *elf.Elf64, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{ .mode = 0o777 });
    defer file.close();

    const fileWriter = file.writer();

    const aligned_shrd = elf.helpers.getAlignment(elf_.header.shoff, 16) - elf_.header.shoff;
    elf_.header.shoff += aligned_shrd;

    try writeHeader(fileWriter, elf_.header);

    if (elf_.pheaders) |ph| {
        try writePHeader(fileWriter, ph);
    }

    try writeSections(fileWriter, elf_.sections);
    if (aligned_shrd != 0) {
        try writeZeroBytes(fileWriter, aligned_shrd);
    }

    try writeSHeader(fileWriter, elf_.sheaders);
}

pub fn writeZeroBytes(write: std.fs.File.Writer, n: usize) !void {
    try write.writeByteNTimes(0, n);
}
