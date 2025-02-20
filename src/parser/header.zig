const std = @import("std");
const utils = @import("utils.zig");

const magic_bytes = [4]u8{ 0x7F, 0x45, 0x4C, 0x46 };

pub const ElfHeader = struct {
    class: u8,
    data: std.builtin.Endian,
    version: u8,
    osabi: u8,
    abiversion: u8,
    type: u16,
    machine: u16,
    file_version: u32,
    entry: u64,
    phoff: u64,
    shoff: u64,
    flags: u32,
    ehsize: u16,
    phentsize: u16,
    phnum: u16,
    shentsize: u16,
    shnum: u16,
    shstrndx: u16,

    pub fn new(allocator: std.mem.Allocator, bytes: []const u8) !ElfHeader {
        _ = allocator;

        if (!std.mem.eql(u8, bytes[0..4], &magic_bytes)) {
            std.debug.panic("Error: File is not an ELF file\n", .{});
        }

        const endian = utils.getEndianness(bytes[0..16]);

        return ElfHeader{
            .class = bytes[4],
            .data = endian,
            .version = bytes[6],
            .osabi = bytes[7],
            .abiversion = bytes[8],
            .type = utils.readInt(u16, bytes, 16, endian),
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
};
