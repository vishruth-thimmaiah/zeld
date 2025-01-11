const std = @import("std");
const parser = @import("../parser/elf.zig");

const sectionLinker = @import("sections/sections.zig");

pub const ElfLinker = struct {
    files: []const parser.Elf64,
    out: parser.Elf64,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, files: []const parser.Elf64) ElfLinker {
        return ElfLinker{
            .files = files[1..],
            .out = files[0],

            .allocator = allocator,
        };
    }

    pub fn link(self: *const ElfLinker) !void {
        for (self.files) |file| {
            self.verify(file);

            try self.merge(file);
        }
    }
    fn verify(self: *const ElfLinker, file: parser.Elf64) void {
        if (self.out.header.type != 1 or file.header.type != 1) {
            std.debug.panic("File type is not yet supported", .{});
        }
    }

    fn merge(self: *const ElfLinker, file: parser.Elf64) !void {
        try sectionLinker.mergeSections(self, file);
    }
};
