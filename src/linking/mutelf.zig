const std = @import("std");

const parser = @import("parser");
const ElfHeader = parser.ElfHeader;
const ElfSectionHeader = parser.ElfSectionHeader;
const ElfSection = parser.ElfSection;
const ElfSymbol = parser.ElfSymbol;
const buildSHeaders = @import("sheaders.zig").buildSHeaders;

pub const MutElf64 = struct {
    header: ElfHeader,
    symbols: std.ArrayList(ElfSymbol),
    sections: std.ArrayList(ElfSection),

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, file: parser.Elf64) !MutElf64 {
        var mutSymbols = std.ArrayList(ElfSymbol).init(allocator);
        try mutSymbols.appendSlice(file.symbols);
        var mutSections = std.ArrayList(ElfSection).init(allocator);
        try mutSections.appendSlice(file.sections);

        return MutElf64{
            .header = file.header,
            .symbols = mutSymbols,
            .sections = mutSections,

            .allocator = allocator,
        };
    }

    pub fn toElf64(self: *MutElf64, shstrtab_names: std.StringHashMap(u32)) !parser.Elf64 {
        return parser.Elf64{
            .header = self.header,
            .sheaders = try buildSHeaders(self.allocator, self.sections.items, shstrtab_names),
            .symbols = try self.symbols.toOwnedSlice(),
            .sections = try self.sections.toOwnedSlice(),
            .all_sections = undefined,

            .allocator = self.allocator,
        };
    }

    pub fn deinit(self: *const MutElf64) void {
        self.symbols.deinit();
        self.sections.deinit();
    }
};
