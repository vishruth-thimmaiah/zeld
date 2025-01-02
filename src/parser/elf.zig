const std = @import("std");
const ElfHeader = @import("header.zig").ElfHeader;
const ElfSectionHeader = @import("sheader.zig").SectionHeader;
const ElfSection = @import("sections.zig").ElfSection;
const ElfSymbol = @import("symbols.zig").ElfSymbol;
const ElfRelocations = @import("relocations.zig").ElfRelocations;

pub const Elf64 = struct {
    header: ElfHeader,
    sheaders: []ElfSectionHeader,
    all_sections: []ElfSection,
    symbols: []ElfSymbol,
    sections: []ElfSection,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, file: std.fs.File) !Elf64 {
        const stat = try file.stat();
        const filebuffer = try file.readToEndAlloc(allocator, stat.size);
        defer allocator.free(filebuffer);

        const fileHeader = try ElfHeader.new(allocator, filebuffer);
        const sheaders = try ElfSectionHeader.new(allocator, filebuffer, fileHeader);
        const all_sections = try ElfSection.new(allocator, filebuffer, fileHeader, sheaders);

        var section = std.ArrayList(ElfSection).init(allocator);
        defer section.deinit();

        var symtab_index: usize = undefined;
        var rela_index: usize = undefined;

        for (sheaders, 0..) |sheader, i| {
            switch (sheader.type) {
                2 => symtab_index = i,
                4 => rela_index = i,
                else => {
                    try section.append(all_sections[i]);
                },
            }
        }
        const symbols = try ElfSymbol.new(allocator, fileHeader, sheaders, all_sections, symtab_index);
        try ElfRelocations.get(allocator, fileHeader, all_sections, rela_index);

        return Elf64{
            .header = fileHeader,
            .sheaders = sheaders,
            .all_sections = all_sections,
            .symbols = symbols,
            .sections = try section.toOwnedSlice(),

            .allocator = allocator,
        };
    }
    pub fn deinit(self: *const Elf64) void {
        self.allocator.free(self.sheaders);
        self.allocator.free(self.symbols);
        for (self.all_sections) |section| {
            section.deinit();
        }
        self.allocator.free(self.all_sections);
        self.allocator.free(self.sections);
    }
};
