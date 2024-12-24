const std = @import("std");
const ElfHeader = @import("header.zig").ElfHeader;

pub const SectionHeader = struct {
    name: u32,
    type: u32,
    flags: u64,
    addr: u64,
    offset: u64,
    size: u64,
    link: u32,
    info: u32,
    addralign: u64,
    entsize: u64,

    pub fn new(allocator: std.mem.Allocator, bytes: []const u8, fheader: ElfHeader) ![]SectionHeader {
        var offset: usize = fheader.shoff;
        const endian = fheader.data;

        var headers = std.ArrayList(SectionHeader).init(allocator);
        defer headers.deinit();

        for (fheader.shnum) |_| {
            const header = SectionHeader{
                .name = std.mem.readInt(u32, bytes[offset .. offset + 4][0..4], endian),
                .type = std.mem.readInt(u32, bytes[offset + 4 .. offset + 8][0..4], endian),
                .flags = std.mem.readInt(u64, bytes[offset + 8 .. offset + 16][0..8], endian),
                .addr = std.mem.readInt(u64, bytes[offset + 16 .. offset + 24][0..8], endian),
                .offset = std.mem.readInt(u64, bytes[offset + 24 .. offset + 32][0..8], endian),
                .size = std.mem.readInt(u64, bytes[offset + 32 .. offset + 40][0..8], endian),
                .link = std.mem.readInt(u32, bytes[offset + 40 .. offset + 44][0..4], endian),
                .info = std.mem.readInt(u32, bytes[offset + 44 .. offset + 48][0..4], endian),
                .addralign = std.mem.readInt(u64, bytes[offset + 48 .. offset + 56][0..8], endian),
                .entsize = std.mem.readInt(u64, bytes[offset + 56 .. offset + 64][0..8], endian),
            };
            try headers.append(header);
            offset += fheader.shentsize;
        }
        return headers.toOwnedSlice();
    }
};
