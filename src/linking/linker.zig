const std = @import("std");
const parser = @import("../parser/elf.zig");

pub const ElfLinker = struct {
    files: []const parser.Elf64,
    out: parser.Elf64,

    pub fn new(files: []const parser.Elf64) ElfLinker {
        return ElfLinker{
            .files = files[1..],
            .out = files[0],
        };
    }

    pub fn link(self: *const ElfLinker) !void {
        for (self.files) |file| {
            _ = file;
        }
    }
};
