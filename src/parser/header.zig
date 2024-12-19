const std = @import("std");

const magic_bytes = [4]u8{ 0x7F, 0x45, 0x4C, 0x46 };

pub const ElfHeader = struct {
    class: u8,
    data: u8,
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
        var magic: [16]u8 = undefined;
        @memcpy(magic[0..], bytes[0..16]);

        if (!std.mem.eql(u8, magic[0..4], &magic_bytes)) {
            std.debug.print("Error: File is not an ELF file\n", .{});
        }

        const endian = getEndianness(magic);

        return ElfHeader{
            .class = magic[4],
            .data = magic[5],
            .version = magic[6],
            .osabi = magic[7],
            .abiversion = magic[8],
            .type = std.mem.readInt(u16, bytes[16..18], endian),
            .machine = std.mem.readInt(u16, bytes[18..20], endian),
            .file_version = std.mem.readInt(u32, bytes[20..24], endian),
            .entry = std.mem.readInt(u64, bytes[24..32], endian),
            .phoff = std.mem.readInt(u64, bytes[32..40], endian),
            .shoff = std.mem.readInt(u64, bytes[40..48], endian),
            .flags = std.mem.readInt(u32, bytes[48..52], endian),
            .ehsize = std.mem.readInt(u16, bytes[52..54], endian),
            .phentsize = std.mem.readInt(u16, bytes[54..56], endian),
            .phnum = std.mem.readInt(u16, bytes[56..58], endian),
            .shentsize = std.mem.readInt(u16, bytes[58..60], endian),
            .shnum = std.mem.readInt(u16, bytes[60..62], endian),
            .shstrndx = std.mem.readInt(u16, bytes[62..64], endian),
        };
    }
    fn getEndianness(magic: [16]u8) std.builtin.Endian {
        switch (magic[5]) {
            0x01 => return std.builtin.Endian.little,
            0x02 => return std.builtin.Endian.big,
            else => unreachable,
        }
    }
};
