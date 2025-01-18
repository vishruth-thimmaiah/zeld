const std = @import("std");

const parser = @import("parser");
const ElfHeader = parser.ElfHeader;
const ElfSectionHeader = parser.ElfSectionHeader;
const ElfSection = parser.ElfSection;
const ElfSymbol = parser.ElfSymbol;

pub const MutElf64 = struct {
    header: ElfHeader,
    sheaders: std.ArrayList(ElfSectionHeader),
    symbols: std.ArrayList(ElfSymbol),
    sections: std.ArrayList(ElfSection),

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, file: parser.Elf64) !MutElf64 {
        var mutSheaders = std.ArrayList(ElfSectionHeader).init(allocator);
        try mutSheaders.appendSlice(file.sheaders);
        var mutSymbols = std.ArrayList(ElfSymbol).init(allocator);
        try mutSymbols.appendSlice(file.symbols);
        var mutSections = std.ArrayList(ElfSection).init(allocator);
        try mutSections.appendSlice(file.sections);

        return MutElf64{
            .header = file.header,
            .sheaders = mutSheaders,
            .symbols = mutSymbols,
            .sections = mutSections,

            .allocator = allocator,
        };
    }

    pub fn toElf64(self: *MutElf64) !parser.Elf64 {
        return parser.Elf64{
            .header = self.header,
            .sheaders = try self.sheaders.toOwnedSlice(),
            .symbols = try self.symbols.toOwnedSlice(),
            .sections = try self.sections.toOwnedSlice(),
            .all_sections = undefined,

            .allocator = self.allocator,
        };
    }

    pub fn deinit(self: *const MutElf64) void {
        self.sheaders.deinit();
        self.symbols.deinit();
        self.sections.deinit();
    }
};
