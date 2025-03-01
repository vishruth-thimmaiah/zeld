const std = @import("std");
const utils = @import("utils.zig");

const ElfHeader = @import("header.zig").ElfHeader;

pub const SectionHeader = struct {
    name: u32,
    type: SHType,
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
            var link = utils.readInt(u32, bytes, offset + 40, endian);
            if (link != 0) {
                link -= 1;
            }
            var info = utils.readInt(u32, bytes, offset + 44, endian);
            if (info != 0) {
                info -= 1;
            }
            const header = SectionHeader{
                .name = utils.readInt(u32, bytes, offset, endian),
                .type = utils.readInt(SHType, bytes, offset + 4, endian),
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
                try headers.append(header);
            }
            offset += fheader.shentsize;
        }
        return headers.toOwnedSlice();
    }
};

pub const SHType = enum(u32) {
    SHT_NULL,
    SHT_PROGBITS,
    SHT_SYMTAB,
    SHT_STRTAB,
    SHT_RELA,
    SHT_HASH,
    SHT_DYNAMIC,
    SHT_NOTE,
    SHT_NOBITS,
    SHT_REL,
    SHT_SHLIB,
    SHT_DYNSYM,
    _,
};
