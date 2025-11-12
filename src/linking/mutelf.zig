const std = @import("std");

const elf = @import("elf");
const Header = elf.Header;
const SectionHeader = elf.SectionHeader;
const Section = elf.Section;
const Symbol = elf.Symbol;

pub const MutElf64 = struct {
    header: Header,
    pheaders: ?std.ArrayList(elf.ProgramHeader),
    symbols: std.ArrayList(Symbol),
    sections: std.ArrayList(Section),

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, file: *const elf.Elf64) !MutElf64 {
        var pheaders: ?std.ArrayList(elf.ProgramHeader) = null;
        if (file.pheaders) |ph| {
            pheaders = try std.ArrayList(elf.ProgramHeader).initCapacity(allocator, ph.len);
            try pheaders.?.appendSlice(allocator, ph);
        }

        var mutSymbols: std.ArrayList(Symbol) = .empty;
        try mutSymbols.appendSlice(allocator, file.symbols);
        var mutSections: std.ArrayList(Section) = .empty;
        for (file.sections, 0..) |symbol, idx| {
            try mutSections.append(allocator, symbol);
            mutSections.items[idx].data = try allocator.dupe(u8, symbol.data);
            if (symbol.relocations) |relocations| {
                mutSections.items[idx].relocations = try allocator.dupe(elf.Relocation, relocations);
            }
        }

        return MutElf64{
            .header = file.header,
            .pheaders = pheaders,
            .symbols = mutSymbols,
            .sections = mutSections,

            .allocator = allocator,
        };
    }

    pub fn toElf64(self: *MutElf64, sheaders: []elf.SectionHeader) !elf.Elf64 {
        return elf.Elf64{
            .header = self.header,
            .pheaders = if (self.pheaders) |*pheaders| try pheaders.toOwnedSlice(self.allocator) else null,
            .sheaders = sheaders,
            .symbols = try self.symbols.toOwnedSlice(self.allocator),
            .sections = try self.sections.toOwnedSlice(self.allocator),

            .allocator = self.allocator,
        };
    }

    pub fn deinit(self: *MutElf64) void {
        self.symbols.deinit(self.allocator);
        self.sections.deinit(self.allocator);
    }
};
