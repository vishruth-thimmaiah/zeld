const std = @import("std");
const ElfHeader = @import("header.zig").ElfHeader;

pub const Elf64 = struct {
    header: ElfHeader,

    pub fn new(allocator: std.mem.Allocator, file: std.fs.File) !Elf64 {
        const stat = try file.stat();
        const filebuffer = try file.readToEndAlloc(allocator, stat.size);
        defer allocator.free(filebuffer);
        return Elf64{
            .header = try ElfHeader.new(allocator, filebuffer),
        };
    }
};
