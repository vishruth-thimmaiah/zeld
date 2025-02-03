const std = @import("std");

const parser = @import("parser");
const ElfLinker = @import("linker.zig").ElfLinker;
const ElfSymbol = parser.ElfSymbol;
const ElfSection = parser.ElfSection;

pub fn mergeSymbols(linker: *ElfLinker, file: parser.Elf64) !void {
    var self_symbols = std.StringHashMap(usize).init(linker.allocator);
    defer self_symbols.deinit();

    for (linker.mutElf.symbols.items, 0..) |*symbol, i| {
        try self_symbols.put(symbol.name, i);
    }
    for (file.symbols) |symbol| {
        if (symbol.name.len == 0) {
            continue;
        }
        if (self_symbols.get(symbol.name)) |idx| {
            try linker.mutElf.symbols.append(symbol);
            _ = linker.mutElf.symbols.swapRemove(idx);
        } else {
            try linker.mutElf.symbols.append(symbol);
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


    const strtab = ElfSection {
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

fn buildSymbolSection(allocator: std.mem.Allocator, symbol: []const ElfSymbol, names: *std.ArrayList(u8), symbols_index: usize) !ElfSection {

    
    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();

    for (symbol) |sym| {
        try names.appendSlice(sym.name);
        try names.append(0);

        const offset = names.items.len;
        var name: [8]u8 = undefined;
        std.mem.writeInt(usize, &name, offset, std.builtin.Endian.little);
        var shndx: [2]u8 = undefined;
        std.mem.writeInt(u16, &shndx, sym.shndx, std.builtin.Endian.little);
        var value: [8]u8 = undefined;
        std.mem.writeInt(u64, &value, sym.value, std.builtin.Endian.little);
        var size: [8]u8 = undefined;
        std.mem.writeInt(u64, &size, sym.size, std.builtin.Endian.little);

        try data.appendSlice(name[0..4]);
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
        .info = 0,
        .addralign = 8,
        .relocations = null,
        .entsize = 24,

        .allocator = allocator,
    };
}
