const std = @import("std");
const parser = @import("parser");
const ElfLinker = @import("linker.zig").ElfLinker;
const helpers = @import("helpers.zig");

pub fn mergeSymbols(linker: *ElfLinker, file: parser.Elf64, section_map: std.StringHashMap(usize)) !void {
    var symbol_map = std.StringHashMap(usize).init(linker.allocator);
    defer symbol_map.deinit();

    // Keep track of original global symbols
    var original_symbols = std.ArrayList([]const u8).init(linker.allocator);
    defer original_symbols.deinit();

    // Globals come after local symbols
    var global_ptr: usize = 0;

    for (linker.mutElf.symbols.items, 0..) |*symbol, i| {
        const name = get_symbol_name(linker.mutElf.symbols.items, linker.mutElf.sections.items, i);
        try symbol_map.put(name, i);
        try original_symbols.append(name);
        if (symbol.get_bind() == .STB_GLOBAL and global_ptr == 0) {
            global_ptr = i;
        }
    }

    const global_start = global_ptr;

    for (file.symbols, 0..) |*symbol, idx| {
        if (symbol.name.len == 0) {
            continue;
        }
        // If the symbol's section index is set, we need to update it.
        if (symbol.shndx != 0 and symbol.shndx != 0xFFF1) {
            const old_section = file.sections[symbol.shndx - 1];
            symbol.shndx = get_section_of_symbol(symbol.*, file, section_map) + 1;
            // If the symbol's bind is global, we need to update the value. Here value is the offset from the start of the section.
            if (symbol.get_bind() == .STB_GLOBAL) {
                const diff = linker.mutElf.sections.items[symbol.shndx - 1].data.len - old_section.data.len;
                symbol.value += diff;
            }
        }

        // If the symbol is already in the map, we need to update it.
        // * FIXME: For now, we assume that the symbol is global.
        // Otherwise, we either append it if it's a global symbol, or insert
        // it if it's a local symbol, right before the global symbol.
        if (symbol_map.get(symbol.name)) |index| {
            if (symbol.shndx != 0) {
                linker.mutElf.symbols.items[index + (global_ptr - global_start)] = symbol.*;
            }
        } else if (symbol.get_bind() == .STB_GLOBAL) {
            try linker.mutElf.symbols.append(symbol.*);
            try symbol_map.put(get_symbol_name(file.symbols, file.sections, idx), linker.mutElf.symbols.items.len - 1);
        } else {
            try linker.mutElf.symbols.insert(global_ptr, symbol.*);
            try symbol_map.put(get_symbol_name(file.symbols, file.sections, idx), global_ptr);
            global_ptr += 1;
        }
    }

    // Update the indexes of the global symbols that were already in the map.
    for (original_symbols.items[global_start..]) |global| {
        const val = try symbol_map.getOrPut(global);
        val.value_ptr.* += global_ptr - global_start;
    }

    // Handles relocations
    for (linker.mutElf.sections.items) |*section| {
        if (section.relocations) |relocations| {
            const rela_len = relocations.len;
            var other_relas: ?[]parser.ElfRelocations = undefined;
            for (file.sections) |other_section| {
                if (std.mem.eql(u8, other_section.name, section.name)) {
                    other_relas = other_section.relocations;
                }
            }
            const other_rela_count = if (other_relas) |rels| rels.len else 0;

            // For new relocations, we need to update the symbol indexes. We
            // also need to update the addend. This is equal to the size of the
            // initial section the associated symbol references.
            for (relocations[rela_len - other_rela_count ..]) |*rela| {
                const name = get_symbol_name(file.symbols, file.sections, rela.get_symbol());
                const idx = symbol_map.get(name).?;

                rela.set_symbol(idx);
                const symbol = linker.mutElf.symbols.items[idx];
                if (symbol.info == 3) {
                    const other_symbol = file.symbols[idx];
                    const diff = linker.mutElf.sections.items[symbol.shndx - 1].data.len - file.sections[other_symbol.shndx - 1].data.len;
                    rela.addend += @intCast(diff);
                }
            }
            // For old relocations, we just need to update the symbol indexes.
            for (relocations[0 .. rela_len - other_rela_count]) |*rela| {
                const name = original_symbols.items[rela.get_symbol()];
                rela.set_symbol(symbol_map.get(name).?);
            }
        }
    }
}

fn get_section_of_symbol(symbol: parser.ElfSymbol, file: parser.Elf64, section_map: std.StringHashMap(usize)) u16 {
    const shndx = symbol.shndx;
    const section = file.sections[shndx - 1];

    return @intCast(section_map.get(section.name) orelse return shndx);
}

fn get_idx_of_symbol(index: usize, file: parser.Elf64, symbol_map: std.StringHashMap(usize)) usize {
    const name = get_symbol_name(file.symbols, file.sections, index);
    return symbol_map.get(name).?;
}

fn get_symbol_name(symbols: []parser.ElfSymbol, sections: []parser.ElfSection, index: usize) []const u8 {
    const symbol = symbols[index];

    if (symbol.name.len == 0) {
        if (symbol.shndx == 0) {
            return "";
        }
        return sections[symbol.shndx - 1].name;
    }
    return symbol.name;
}

pub fn addSymbolSections(self: *ElfLinker) !void {
    var names = std.ArrayList(u8).init(self.allocator);
    defer names.deinit();

    const symbols = self.mutElf.symbols.items;
    const symbols_index = self.mutElf.sections.items.len;
    const section = try buildSymbolSection(
        self.allocator,
        symbols,
        &names,
        self.mutElf.sections.items,
        symbols_index + 1,
    );
    try self.mutElf.sections.append(section);

    const strtab = parser.ElfSection{
        .name = ".strtab",
        .type = .SHT_STRTAB,
        .flags = 0,
        .addr = 0,
        .link = 0,
        .info = 0,
        .addralign = 1,
        .data = try names.toOwnedSlice(),
        .entsize = 0,
        .relocations = null,

        .allocator = self.allocator,
    };
    try self.mutElf.sections.append(strtab);
}

fn buildSymbolSection(
    allocator: std.mem.Allocator,
    symbol: []const parser.ElfSymbol,
    names: *std.ArrayList(u8),
    sections: []const parser.ElfSection,
    symbols_index: usize,
) !parser.ElfSection {
    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();
    try names.append(0);

    var section_indexes = try allocator.alloc(u16, sections.len);
    defer allocator.free(section_indexes);
    var idx: usize = 0;
    for (sections, 0..) |section, i| {
        section_indexes[i] = @intCast(idx);
        idx = if (section.relocations) |_| idx + 2 else idx + 1;
    }

    var global_start: usize = 0;

    for (symbol, 0..) |sym, i| {
        if (global_start == 0 and sym.get_bind() == .STB_GLOBAL) {
            global_start = i;
        }

        var name: [4]u8 = undefined;

        if (sym.name.len != 0) {
            const offset: u32 = @intCast(names.items.len);
            std.mem.writeInt(u32, &name, offset, std.builtin.Endian.little);
            try names.appendSlice(sym.name);
            try names.append(0);
        } else {
            name = std.mem.zeroes([4]u8);
        }

        var shndx: [2]u8 = undefined;
        if (sym.shndx != 0 and sym.shndx < 0xFFF1) {
            std.mem.writeInt(u16, &shndx, section_indexes[sym.shndx - 1] + 1, std.builtin.Endian.little);
        } else {
            std.mem.writeInt(u16, &shndx, sym.shndx, std.builtin.Endian.little);
        }
        var value: [8]u8 = undefined;
        std.mem.writeInt(u64, &value, sym.value, std.builtin.Endian.little);
        var size: [8]u8 = undefined;
        std.mem.writeInt(u64, &size, sym.size, std.builtin.Endian.little);

        try data.appendSlice(&name);
        try data.append(sym.info);
        try data.append(sym.other);
        try data.appendSlice(&shndx);
        try data.appendSlice(&value);
        try data.appendSlice(&size);
    }

    return parser.ElfSection{
        .name = ".symtab",
        .data = try data.toOwnedSlice(),
        .type = .SHT_SYMTAB,
        .flags = 0,
        .addr = 0,
        .link = @intCast(symbols_index + 1),
        // info is the index of the first global symbol
        .info = @intCast(global_start),
        .addralign = 8,
        .relocations = null,
        .entsize = 24,

        .allocator = allocator,
    };
}
