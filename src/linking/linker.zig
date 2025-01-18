const std = @import("std");
const parser = @import("../parser/elf.zig");

const sectionLinker = @import("sections/sections.zig");
const symbolLinker = @import("symbols.zig");
const mutElf64 = @import("mutelf.zig").MutElf64;

pub const ElfLinker = struct {
    files: []const parser.Elf64,
    out: parser.Elf64,
    mutElf: mutElf64,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, files: []const parser.Elf64) !ElfLinker {
        const mutElf = try mutElf64.new(allocator, files[0]);
        errdefer mutElf.deinit();

        return ElfLinker{
            .files = files[1..],
            .out = undefined,
            .mutElf = mutElf,

            .allocator = allocator,
        };
    }

    pub fn link(self: *ElfLinker) !void {
        errdefer self.mutElf.deinit();
        for (self.files) |file| {
            self.verify(file);

            try self.merge(file);
        }
        self.out = try self.mutElf.toElf64();
    }

    fn verify(self: *ElfLinker, file: parser.Elf64) void {
        if (self.mutElf.header.type != 1 or file.header.type != 1) {
            std.debug.panic("File type is not yet supported", .{});
        }
    }

    fn merge(self: *ElfLinker, file: parser.Elf64) !void {
        try sectionLinker.mergeSections(self, file);
        std.debug.print("Symbols: {d}\n", .{self.mutElf.symbols.items.len});
        try symbolLinker.mergeSymbols(self, file);
        std.debug.print("symbols: {any}\n", .{self.mutElf.symbols.items.len});
    }

    pub fn deinit(self: *const ElfLinker) void {
        self.allocator.free(self.out.sections);
        self.allocator.free(self.out.symbols);
        self.allocator.free(self.out.sheaders);
    }
};
