const ElfLinker = @import("linker.zig").ElfLinker;
const parser = @import("../parser/elf.zig");
const ElfSymbol = @import("../parser/symbols.zig").ElfSymbol;

const std = @import("std");

pub fn mergeSymbols(linker: *ElfLinker, file: parser.Elf64) !void {
    var self_symbols = std.StringHashMap(usize).init(linker.allocator);
    defer self_symbols.deinit();

    for (linker.out.symbols, 0..) |*symbol, i| {
        try self_symbols.put(symbol.name, i);
    }
    var symbols = &linker.out.symbols;
    var new_symbols = std.ArrayList(ElfSymbol).init(linker.allocator);
    defer new_symbols.deinit();
    try new_symbols.appendSlice(symbols.*);

    for (file.symbols) |symbol| {
        if (symbol.name.len == 0) {
            continue;
        }
        if (self_symbols.get(symbol.name)) |idx| {
            linker.out.symbols[idx] = symbol;
        } else {
            try new_symbols.append(symbol);
            // var new_symbols = try linker.allocator.alloc(ElfSymbol, symbols.*.len+1);
            // defer linker.allocator.free(new_symbols);
            // @memcpy(new_symbols[0..symbols.*.len], symbols.*[0..symbols.*.len]);
            // new_symbols[symbols.*.len] = symbol;
            // symbols = &new_symbols;
            // std.debug.print("Test: {d}\n", .{linker.out.symbols.len});
        }
    }
    var result = try new_symbols.toOwnedSlice();
    symbols = &result;
}
