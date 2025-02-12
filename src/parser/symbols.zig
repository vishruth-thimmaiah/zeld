const std = @import("std");

const ElfHeader = @import("header.zig").ElfHeader;
const ElfSectionHeader = @import("sheader.zig").SectionHeader;
const ElfSection = @import("sections.zig").ElfSection;

pub const ElfSymbol = struct {
    name: []const u8, // Pointer is 32 bits.
    info: u8,
    other: u8,
    shndx: u16,
    value: u64,
    size: u64,

    pub fn new(allocator: std.mem.Allocator, header: ElfHeader, sheaders: []ElfSectionHeader, sections: []ElfSection, symtab_index: usize) ![]ElfSymbol {
        var symbols = try std.ArrayList(ElfSymbol).initCapacity(allocator, sheaders.len);
        defer symbols.deinit();

        const symtab_header = sheaders[symtab_index];
        const symtab = sections[symtab_index];

        const string_section = sections[symtab.link];

        for (0..symtab_header.size / symtab_header.entsize) |i| {
            const offset = symtab_header.entsize * i;
            const name_offset = std.mem.readInt(u32, symtab.data[offset .. offset + 4][0..4], header.data);
            const symbol = ElfSymbol{
                .name = try getSymbolName(name_offset, string_section.data),
                .info = std.mem.readInt(u8, symtab.data[offset + 4 .. offset + 5][0..1], header.data),
                .other = std.mem.readInt(u8, symtab.data[offset + 5 .. offset + 6][0..1], header.data),
                .shndx = std.mem.readInt(u16, symtab.data[offset + 6 .. offset + 8][0..2], header.data),
                .value = std.mem.readInt(u64, symtab.data[offset + 8 .. offset + 16][0..8], header.data),
                .size = std.mem.readInt(u64, symtab.data[offset + 16 .. offset + 24][0..8], header.data),
            };

            try symbols.append(symbol);
        }

        return symbols.toOwnedSlice();
    }

    pub fn get_bind(self: ElfSymbol) usize {
        return self.info >> 4;
    }

    pub fn get_type(self: ElfSymbol) usize {
        return self.info & 0xf;
    }

    fn getSymbolName(idx: u32, bytes: []const u8) ![]const u8 {
        var end_offset = idx;

        while (true) {
            if (bytes[end_offset] == 0) {
                break;
            }
            end_offset += 1;
        }

        return bytes[idx..end_offset];
    }
};
