const std = @import("std");
const utils = @import("utils.zig");

const elf = @import("elf");

pub fn parse(
    allocator: std.mem.Allocator,
    header: elf.Header,
    sheaders: []elf.SectionHeader,
    sections: []elf.Section,
    symtab_index: usize,
) ![]elf.Symbol {
    var symbols = try std.ArrayList(elf.Symbol).initCapacity(allocator, sheaders.len);
    defer symbols.deinit();

    const symtab_header = sheaders[symtab_index];
    const symtab = sections[symtab_index];
    defer symtab.deinit();

    const string_section = sections[symtab.link];
    defer string_section.deinit();

    for (0..symtab_header.size / symtab_header.entsize) |i| {
        const offset = symtab_header.entsize * i;
        const name_offset = utils.readInt(u32, symtab.data, offset, header.data);
        const shndx = utils.readInt(u16, symtab.data, offset + 6, header.data);
        const symbol = elf.Symbol{
            .name = try allocator.dupe(u8, getSymbolName(name_offset, string_section.data)),
            .info = utils.readInt(u8, symtab.data, offset + 4, header.data),
            .other = utils.readInt(u8, symtab.data, offset + 5, header.data),
            .shndx = elf.STNdx.fromInt(shndx, sections),
            .value = utils.readInt(u64, symtab.data, offset + 8, header.data),
            .size = utils.readInt(u64, symtab.data, offset + 16, header.data),

            .allocator = allocator,
        };

        try symbols.append(symbol);
    }

    return symbols.toOwnedSlice();
}

fn getSymbolName(idx: u32, bytes: []const u8) []const u8 {
    var end_offset = idx;

    while (true) {
        if (bytes[end_offset] == 0) {
            break;
        }
        end_offset += 1;
    }

    return bytes[idx..end_offset];
}
