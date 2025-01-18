const std = @import("std");

const parser = @import("parser");
const ElfLinker = @import("linker.zig").ElfLinker;

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
