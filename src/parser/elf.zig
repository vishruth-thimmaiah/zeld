const std = @import("std");
const ElfHeader = @import("header.zig").ElfHeader;
const ElfSectionHeader = @import("sheader.zig").SectionHeader;
const ElfSection = @import("sections.zig").ElfSection;
const ElfSymbol = @import("symbols.zig").ElfSymbol;

pub const Elf64 = struct {
    header: ElfHeader,
    sheaders: []ElfSectionHeader,
    sections: []ElfSection,
    symbols: []ElfSymbol,

    pub fn new(allocator: std.mem.Allocator, file: std.fs.File) !Elf64 {
        const stat = try file.stat();
        const filebuffer = try file.readToEndAlloc(allocator, stat.size);
        defer allocator.free(filebuffer);

        const fileHeader = try ElfHeader.new(allocator, filebuffer);
        const sheaders = try ElfSectionHeader.new(allocator, filebuffer, fileHeader);
        defer allocator.free(sheaders);
        const section = try ElfSection.new(allocator, filebuffer, fileHeader, sheaders);
        defer allocator.free(section);
        const symbols = try ElfSymbol.new(allocator, fileHeader, sheaders, section, filebuffer);
        defer allocator.free(symbols);

        return Elf64{
            .header = fileHeader,
            .sheaders = sheaders,
            .sections = section,
            .symbols = symbols,
        };
    }
};
