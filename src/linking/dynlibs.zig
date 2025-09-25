const std = @import("std");

const elf = @import("elf");
const linker = @import("linker.zig");
const parser = @import("parser");

pub fn resolve(self: *linker.ElfLinker, reloc_map: *std.StringHashMap(*elf.Symbol)) !void {
    for (self.args.shared_libs) |*lib| {
        const dynlib = try parser.dynlibs.Dynlib.new(self.allocator, lib);
        defer dynlib.deinit();

        dynlib.checkSym(reloc_map);
    }
}
