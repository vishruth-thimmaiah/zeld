const std = @import("std");
const utils = @import("utils.zig");
const elf = @import("elf");

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8, fheader: elf.Header) ![]elf.SectionHeader {
    var offset: usize = fheader.shoff;
    const endian = fheader.data;

    var headers: std.ArrayList(elf.SectionHeader) = .empty;
    defer headers.deinit(allocator);

    for (0..fheader.shnum) |_| {
        var link = utils.readInt(u32, bytes, offset + 40, endian);
        if (link != 0) {
            link -= 1;
        }
        var info = utils.readInt(u32, bytes, offset + 44, endian);
        if (info != 0) {
            info -= 1;
        }
        const header = elf.SectionHeader{
            .name = utils.readInt(u32, bytes, offset, endian),
            .type = utils.readInt(elf.SectionHeader.Type, bytes, offset + 4, endian),
            .flags = utils.readInt(u64, bytes, offset + 8, endian),
            .addr = utils.readInt(u64, bytes, offset + 16, endian),
            .offset = utils.readInt(u64, bytes, offset + 24, endian),
            .size = utils.readInt(u64, bytes, offset + 32, endian),
            .link = link,
            .info = info,
            .addralign = utils.readInt(u64, bytes, offset + 48, endian),
            .entsize = utils.readInt(u64, bytes, offset + 56, endian),
        };
        if (header.type != .SHT_NULL) {
            try headers.append(allocator, header);
        }
        offset += fheader.shentsize;
    }
    return try headers.toOwnedSlice(allocator);
}
