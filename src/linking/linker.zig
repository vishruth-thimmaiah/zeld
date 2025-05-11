const std = @import("std");
const elf = @import("elf");

const relocations = @import("relocations.zig");
const shstrtab = @import("shstrtab.zig");
const newSectionMerger = @import("sections.zig");
const newSymbolMerger = @import("symbols.zig");
const MutElf64 = @import("mutelf.zig").MutElf64;

pub const ElfLinker = struct {
    files: []const elf.Elf64,
    out: elf.Elf64,
    mutElf: MutElf64,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, files: []const elf.Elf64) !ElfLinker {
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
            var section_map = try newSectionMerger.mergeSections(self, file);
            defer section_map.deinit();
            try newSymbolMerger.mergeSymbols(self, file, section_map);
        }
        try relocations.addRelocationSections(self);
        try newSymbolMerger.addSymbolSections(self);
        var shstrtab_names = try shstrtab.buildShstrtab(self);
        defer shstrtab_names.deinit();
        self.updateHeader();
        self.out = try self.mutElf.toElf64(shstrtab_names);
    }

    fn verify(self: *ElfLinker, file: elf.Elf64) void {
        if (self.mutElf.header.type != 1 or file.header.type != 1) {
            std.debug.panic("File type is not yet supported", .{});
        }
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
            if (section.relocations) |rela| {
                self.allocator.free(rela);
            }
        }
        self.allocator.free(self.out.sections);
        self.allocator.free(self.out.symbols);
        self.allocator.free(self.out.sheaders);
    }
};
