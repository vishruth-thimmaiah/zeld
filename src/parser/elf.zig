const std = @import("std");
const ElfHeader = @import("header.zig").ElfHeader;
const SectionHeader = @import("sheader.zig").SectionHeader;

pub const Elf64 = struct {
    header: ElfHeader,
    sheaders: std.ArrayList(SectionHeader),

    pub fn new(allocator: std.mem.Allocator, file: std.fs.File) !Elf64 {
        const stat = try file.stat();
        const filebuffer = try file.readToEndAlloc(allocator, stat.size);
        defer allocator.free(filebuffer);

        const fileHeader = try ElfHeader.new(allocator, filebuffer);
        const sheaders = try SectionHeader.new(allocator, filebuffer, fileHeader);

        return Elf64{
            .header = fileHeader,
            .sheaders = sheaders,
        };
    }
};
