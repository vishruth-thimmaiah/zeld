const std = @import("std");
const elf = @import("elf");
const writeHeader = @import("header.zig").writeHeader;
const writeSHeader = @import("sheader.zig").writeSHeader;
const writeSections = @import("sections.zig").writeSections;
const writePHeader = @import("pheader.zig").writePHeader;

pub fn writer(elf_: *elf.Elf64, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{ .mode = 0o777 });
    defer file.close();

    var buf: [4096]u8 = undefined;
    var fsWriter = file.writer(&buf);
    const interface = &fsWriter.interface;

    const aligned_shrd = elf.helpers.getAlignment(elf_.header.shoff, 16) - elf_.header.shoff;
    elf_.header.shoff += aligned_shrd;

    try writeHeader(interface, elf_.header);

    if (elf_.pheaders) |ph| {
        try writePHeader(interface, ph);
    }

    try writeSections(interface, elf_.sections);
    if (aligned_shrd != 0) {
        try writeZeroBytes(interface, aligned_shrd);
    }

    try writeSHeader(interface, elf_.sheaders);

    // Flush the buffer to ensure all data is written to the file
    try interface.flush();
}

pub fn writeZeroBytes(write: *std.io.Writer, n: usize) !void {
    _ = try write.splatByte(0, n);
}
