const std = @import("std");

const parser = @import("parser");
const ElfLinker = @import("linker.zig").ElfLinker;
const ElfSymbol = parser.ElfSymbol;
const ElfSection = parser.ElfSection;

pub fn mergeSymbols(linker: *ElfLinker, file: parser.Elf64, refs: []?usize) !void {
    var self_symbols = std.StringHashMap(usize).init(linker.allocator);
    defer self_symbols.deinit();

    var symbol_indexes = try linker.allocator.alloc(usize, file.symbols.len);
    defer linker.allocator.free(symbol_indexes);
    symbol_indexes[0] = 0;

    for (linker.mutElf.symbols.items, 0..) |*symbol, i| {
        try self_symbols.put(symbol.name, i);
    }
    for (file.symbols[1..], 1..) |*symbol, i| {
        if (symbol.shndx != 0 and symbol.shndx != 0xFFF1) {
            if (refs[symbol.shndx]) |idx| {
                symbol.shndx = @intCast(idx);
            }
            else {
                symbol.shndx = @intCast(linker.mutElf.sections.items.len);
            }
        }
        const existing = self_symbols.get(symbol.name);
        if (existing) |idx| {
            if (symbol.shndx != 0) {
                try linker.mutElf.symbols.append(symbol.*);
                _ = linker.mutElf.symbols.swapRemove(idx);
                symbol_indexes[i] = idx;
            } else {
                //TODO
                symbol_indexes[i] = idx;
            }
        } else {
            try linker.mutElf.symbols.append(symbol.*);
            symbol_indexes[i] = linker.mutElf.symbols.items.len - 1;
        }
    }

    for (file.sections) |*section| {
        if (section.relocations) |relocations| {
            for (relocations) |*rela| {
                const symbol = symbol_indexes[rela.get_symbol()];
                rela.set_symbol(symbol);
                const sym = file.symbols[symbol];
                if (sym.info == 3) {
                    rela.addend += @intCast(linker.mutElf.sections.items[sym.shndx - 1].data.len);
                }
            }
        }
    }
}

pub fn addSymbolSections(self: *ElfLinker) !usize {
    var names = std.ArrayList(u8).init(self.allocator);
    defer names.deinit();

    const symbols = self.mutElf.symbols.items;
    const symbols_index = self.mutElf.sections.items.len;
    const section = try buildSymbolSection(self.allocator, symbols, &names, symbols_index + 1);
    try self.mutElf.sections.append(section);

    const strtab = ElfSection{
        .name = ".strtab",
        .type = 3,
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
    return symbols_index;
}

fn buildSymbolSection(
    allocator: std.mem.Allocator,
    symbol: []const ElfSymbol,
    names: *std.ArrayList(u8),
    symbols_index: usize,
) !ElfSection {
    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();
    try names.append(0);

    for (symbol) |sym| {

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
        std.mem.writeInt(u16, &shndx, sym.shndx, std.builtin.Endian.little);
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

    return ElfSection{
        .name = ".symtab",
        .data = try data.toOwnedSlice(),
        .type = 2,
        .flags = 0,
        .addr = 0,
        .link = @intCast(symbols_index + 1),
        .info = @intCast(symbols_index),
        .addralign = 8,
        .relocations = null,
        .entsize = 24,

        .allocator = allocator,
    };
}
