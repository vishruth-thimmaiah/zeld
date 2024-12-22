const std = @import("std");
const ElfHeader = @import("header.zig").ElfHeader;
const ElfSectionHeader = @import("sheader.zig").SectionHeader;
const ElfSection = @import("sections.zig").ElfSection;

pub const Elf64 = struct {
    header: ElfHeader,
    sheaders: []ElfSectionHeader,
    sdata: []ElfSection,

    pub fn new(allocator: std.mem.Allocator, file: std.fs.File) !Elf64 {
        const stat = try file.stat();
        const filebuffer = try file.readToEndAlloc(allocator, stat.size);
        defer allocator.free(filebuffer);

        const fileHeader = try ElfHeader.new(allocator, filebuffer);
        const sheaders = try ElfSectionHeader.new(allocator, filebuffer, fileHeader);
        defer allocator.free(sheaders);
        const section = try ElfSection.new(allocator, filebuffer, fileHeader, sheaders);
        defer allocator.free(section);

        return Elf64{
            .header = fileHeader,
            .sheaders = sheaders,
            .sdata = section,
        };
    }
};
