const std = @import("std");
const elf = @import("elf");

const relocations = @import("relocations.zig");
const shstrtab = @import("shstrtab.zig");
const SectionMerger = @import("sections.zig");
const SymbolMerger = @import("symbols.zig");
const PheaderGenerator = @import("pheaders.zig");
const MutElf64 = @import("mutelf.zig").MutElf64;

pub const ElfLinker = struct {
    out: elf.Elf64,
    mutElf: MutElf64,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, file: *const elf.Elf64) !ElfLinker {
        const mutElf = try MutElf64.new(allocator, file);
        errdefer mutElf.deinit();

        return ElfLinker{
            .out = undefined,
            .mutElf = mutElf,

            .allocator = allocator,
        };
    }

    pub fn merge(self: *ElfLinker, file: *const elf.Elf64) !void {
        errdefer self.mutElf.deinit();
        self.verify(file);
        var section_map = try SectionMerger.mergeSections(self, file);
        defer section_map.deinit();
        try SymbolMerger.mergeSymbols(self, file, section_map);
    }

    pub fn link(self: *ElfLinker) !void {
        try relocations.addRelocationSections(self);
        try SymbolMerger.addSymbolSections(self);
        try PheaderGenerator.generatePheaders(self);
        var shstrtab_names = try shstrtab.buildShstrtab(self);
        defer shstrtab_names.deinit();
        self.updateHeader();
        self.out = try self.mutElf.toElf64(shstrtab_names);
    }

    fn verify(self: *ElfLinker, file: *const elf.Elf64) void {
        if (self.mutElf.header.type != 1 or file.header.type != 1) {
            std.debug.panic("File type is not yet supported", .{});
        }
    }

    fn updateHeader(self: *ElfLinker) void {
        const header = &self.mutElf.header;
        var shoff: u64 = header.ehsize;
        var shnum: u16 = 1;
        for (self.mutElf.sections.items) |*section| {
            shoff += section.data.len;
            shnum += 1;
        }

        header.phentsize = 56;
        header.phnum = if (self.mutElf.pheaders) |ph| @intCast(ph.items.len) else 0;
        header.phoff = 64;
        header.shoff = shoff + header.phnum * header.phentsize;
        header.shnum = shnum;
        header.shstrndx = shnum - 1;
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
