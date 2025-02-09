const std = @import("std");
const parser = @import("parser");

const sectionLinker = @import("sections/sections.zig");
const symbolLinker = @import("symbols.zig");
const MutElf64 = @import("mutelf.zig").MutElf64;

pub const ElfLinker = struct {
    files: []const parser.Elf64,
    out: parser.Elf64,
    mutElf: MutElf64,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, files: []const parser.Elf64) !ElfLinker {
        const mutElf = try MutElf64.new(allocator, files[0]);
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
        const symbols_index = try symbolLinker.addSymbolSections(self);
        try sectionLinker.addRelocationSections(self, symbols_index);
        var shstrtab_names = try sectionLinker.buildShstrtab(self);
        defer shstrtab_names.deinit();
        self.updateHeader();
        self.out = try self.mutElf.toElf64(shstrtab_names);
    }

    fn verify(self: *ElfLinker, file: parser.Elf64) void {
        if (self.mutElf.header.type != 1 or file.header.type != 1) {
            std.debug.panic("File type is not yet supported", .{});
        }
    }

    fn merge(self: *ElfLinker, file: parser.Elf64) !void {
        const refs = try sectionLinker.sectionReferences(self, file);
        defer self.allocator.free(refs);
        try symbolLinker.mergeSymbols(self, file, refs);
        try sectionLinker.mergeSections(self, file, refs);
    }

    fn updateHeader(self: *ElfLinker) void {
        var shoff: u64 = self.mutElf.header.ehsize;
        var shnum: u16 = 1;
        for (self.mutElf.sections.items) |*section| {
            shoff += section.data.len;
            shnum += 1;
        }

        self.mutElf.header.shoff = shoff;
        self.mutElf.header.shnum = shnum;
        self.mutElf.header.shstrndx = shnum - 1;
    }

    pub fn deinit(self: *const ElfLinker) void {
        for (self.out.sections) |section| {
            self.allocator.free(section.data);
            if (section.name.len > 4 and std.mem.eql(u8, section.name[0..5], ".rela")) {
                self.allocator.free(section.name);
            }
            if (section.relocations) |relocations| {
                self.allocator.free(relocations);
            }
        }
        self.allocator.free(self.out.sections);
        self.allocator.free(self.out.symbols);
        self.allocator.free(self.out.sheaders);
    }
};
