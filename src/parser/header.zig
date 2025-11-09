const std = @import("std");
const utils = @import("utils.zig");
const elf = @import("elf");

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !elf.Header {
    _ = allocator;

    if (!std.mem.eql(u8, bytes[0..4], &elf.MAGIC_BYTES)) {
        std.debug.panic("Error: File is not an ELF file\n", .{});
    }

    const endian = utils.getEndianness(bytes[0..16]);

    return elf.Header{
        .class = bytes[4],
        .data = endian,
        .version = bytes[6],
        .osabi = bytes[7],
        .abiversion = bytes[8],
        .type = utils.readInt(elf.Header.Type, bytes, 16, endian),
        .machine = utils.readInt(u16, bytes, 18, endian),
        .file_version = utils.readInt(u32, bytes, 20, endian),
        .entry = utils.readInt(u64, bytes, 24, endian),
        .phoff = utils.readInt(u64, bytes, 32, endian),
        .shoff = utils.readInt(u64, bytes, 40, endian),
        .flags = utils.readInt(u32, bytes, 48, endian),
        .ehsize = utils.readInt(u16, bytes, 52, endian),
        .phentsize = utils.readInt(u16, bytes, 54, endian),
        .phnum = utils.readInt(u16, bytes, 56, endian),
        .shentsize = utils.readInt(u16, bytes, 58, endian),
        .shnum = utils.readInt(u16, bytes, 60, endian),
        .shstrndx = utils.readInt(u16, bytes, 62, endian) - 1,
    };
}
