const std = @import("std");
pub const ElfHeader = @import("header.zig").ElfHeader;
pub const ElfSectionHeader = @import("sheader.zig").SectionHeader;
pub const ElfSection = @import("sections.zig").ElfSection;
pub const ElfSymbol = @import("symbols.zig").ElfSymbol;
pub const ElfRelocations = @import("relocations.zig").ElfRelocations;
pub const MAGIC_BYTES = [4]u8{ 0x7F, 0x45, 0x4C, 0x46 };

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

        var sections = std.ArrayList(ElfSection).init(allocator);
        defer sections.deinit();
        var special_section_count: usize = 0;

        var symtab_index: usize = undefined;
        var rela_indexes = std.ArrayList([2]usize).init(allocator);
        defer rela_indexes.deinit();

        for (sheaders, 0..) |sheader, i| {
            try switch (sheader.type) {
                2 => symtab_index = i,
                3 => {},
                4 => rela_indexes.append([2]usize{ i, special_section_count }),
                else => {
                    try sections.append(all_sections[i]);
                    continue;
                },
            };
            special_section_count += 1;
        }
        const symbols = try ElfSymbol.new(allocator, fileHeader, sheaders, all_sections, symtab_index);
        for (rela_indexes.items) |rela_index| {
            const rela_section = all_sections[rela_index[0]];
            try ElfRelocations.get(allocator, fileHeader, sections.items, rela_section, rela_section.info - rela_index[1]);
        }

        return Elf64{
            .header = fileHeader,
            .sheaders = sheaders,
            .all_sections = all_sections,
            .symbols = symbols,
            .sections = try sections.toOwnedSlice(),

            .allocator = allocator,
        };
    }
    pub fn deinit(self: *const Elf64) void {
        self.allocator.free(self.sheaders);
        self.allocator.free(self.symbols);
        for (self.all_sections) |section| {
            section.deinit();
        }
        for (self.sections) |section| {
            if (section.relocations) |relas| {
                self.allocator.free(relas);
            }
        }
        self.allocator.free(self.all_sections);
        self.allocator.free(self.sections);
    }
};
