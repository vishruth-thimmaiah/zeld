const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;
const helpers = @import("helpers.zig");

pub fn mergeSymbols(linker: *ElfLinker, file: *const elf.Elf64, section_map: std.StringHashMap(usize)) !void {
    var symbol_map = std.StringHashMap(usize).init(linker.allocator);
    defer symbol_map.deinit();

    // Keep track of original global symbols
    var original_symbols = std.ArrayList([]const u8).init(linker.allocator);
    defer original_symbols.deinit();

    // Globals come after local symbols
    var global_ptr: usize = 0;

    for (linker.mutElf.symbols.items, 0..) |*symbol, i| {
        const name = symbol.getDisplayName();
        try symbol_map.put(name, i);
        try original_symbols.append(name);
        if (symbol.get_bind() == .STB_GLOBAL and global_ptr == 0) {
            global_ptr = i;
        }
    }

    const global_start = global_ptr;

    for (file.symbols) |*symbol| {
        if (!symbol.shndx.isSpecial()) {
            const section_idx = symbol.shndx.toIntFromMap(section_map);
            const other_section_idx = symbol.shndx.toInt(file.sections);
            const diff = linker.mutElf.sections.items[section_idx].data.len - file.sections[other_section_idx].data.len;
            symbol.value += @intCast(diff);
        }

        // If the symbol is already in the map, we need to update it.
        // * FIXME: For now, we assume that the symbol is global.
        // Otherwise, we either append it if it's a global symbol, or insert
        // it if it's a local symbol, right before the global symbol.
        if (symbol_map.get(symbol.getDisplayName())) |i| {
            if (symbol.shndx != .SHN_UNDEF) {
                const index = if (symbol.get_bind() == .STB_GLOBAL) i + (global_ptr - global_start) else i;
                linker.mutElf.symbols.items[index] = symbol.*;
            }
        } else if (symbol.get_bind() == .STB_GLOBAL) {
            try linker.mutElf.symbols.append(symbol.*);
            try symbol_map.put(symbol.getDisplayName(), linker.mutElf.symbols.items.len - 1);
        } else {
            try linker.mutElf.symbols.insert(global_ptr, symbol.*);
            try symbol_map.put(symbol.getDisplayName(), global_ptr);
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
            var other_relas: ?[]elf.Relocation = undefined;
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
                const other_symbol = file.symbols[rela.get_symbol()];
                const name = other_symbol.getDisplayName();
                const idx = symbol_map.get(name).?;
                rela.set_symbol(idx);

                const symbol = linker.mutElf.symbols.items[idx];
                if (symbol.get_type() == .STT_SECTION) {
                    const section_idx = symbol.shndx.toIntFromMap(section_map);
                    const other_section_idx = other_symbol.shndx.toInt(file.sections);
                    const diff = linker.mutElf.sections.items[section_idx].data.len - file.sections[other_section_idx].data.len;
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

fn get_section_of_symbol(symbol: elf.Symbol, file: elf.Elf64, section_map: std.StringHashMap(usize)) u16 {
    const shndx = symbol.shndx;
    const section = file.sections[shndx - 1];

    return @intCast(section_map.get(section.name) orelse return shndx);
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

    const strtab = elf.Section{
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
    symbols: []const elf.Symbol,
    names: *std.ArrayList(u8),
    sections: []const elf.Section,
    symbols_index: usize,
) !elf.Section {
    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();
    try names.append(0);

    var section_map = std.StringHashMap(usize).init(allocator);
    defer section_map.deinit();
    for (sections, 0..) |section, idx| {
        try section_map.put(section.name, idx);
    }

    var global_start: usize = 0;

    for (symbols, 0..) |sym, i| {
        if (global_start == 0 and sym.get_bind() == .STB_GLOBAL) {
            global_start = i;
        }

        var name: [4]u8 = undefined;

        if (sym.name.len != 0 and sym.get_type() != .STT_SECTION) {
            const offset: u32 = @intCast(names.items.len);
            std.mem.writeInt(u32, &name, offset, std.builtin.Endian.little);
            try names.appendSlice(sym.name);
            try names.append(0);
        } else {
            name = std.mem.zeroes([4]u8);
        }

        var shndx: [2]u8 = undefined;
        if (sym.shndx.isSpecial()) {
            std.mem.writeInt(u16, &shndx, sym.shndx.toIntFromMap(section_map), std.builtin.Endian.little);
        } else {
            std.mem.writeInt(u16, &shndx, sym.shndx.toIntFromMap(section_map) + 1, std.builtin.Endian.little);
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

    return elf.Section{
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
