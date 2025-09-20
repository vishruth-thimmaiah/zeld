const std = @import("std");
const elf = @import("elf");

const relocations = @import("relocations.zig");
const shstrtab = @import("shstrtab.zig");
const SectionMerger = @import("sections.zig");
const SymbolMerger = @import("symbols.zig");
const PheaderGenerator = @import("pheaders.zig");
const dynamic = @import("dynamic.zig");
const buildSHeaders = @import("sheaders.zig").buildSHeaders;
const MutElf64 = @import("mutelf.zig").MutElf64;

pub const LinkerArgs = struct {
    output_type: elf.EType,
    dynamic_linker: ?[]const u8,
    shared_libs: [][]const u8,
};

pub const ElfLinker = struct {
    out: elf.Elf64,
    mutElf: MutElf64,
    args: LinkerArgs,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, file: *const elf.Elf64, args: LinkerArgs) !ElfLinker {
        const mutElf = try MutElf64.new(allocator, file);
        errdefer mutElf.deinit();

        return ElfLinker{
            .out = undefined,
            .mutElf = mutElf,
            .args = args,

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
        try self.addInterpSection();
        if (self.args.output_type == .ET_REL) {
            try relocations.addRelocationSections(self);
        }
        if (self.args.output_type == .ET_EXEC) {
            const dyn = try dynamic.createDynamicSection(self);
            try SectionMerger.organizeSections(self);
            try PheaderGenerator.generatePheaders(self);
            try dynamic.updateDynamicSection(self, dyn);
            try SymbolMerger.updateMemValues(self);
            try relocations.applyRelocations(self);
        }
        try SymbolMerger.addSymbolSections(self);
        var shstrtab_names = try shstrtab.buildShstrtab(self);
        defer shstrtab_names.deinit();
        self.updateHeader();

        const sheaders = try buildSHeaders(self, shstrtab_names);

        self.out = try self.mutElf.toElf64(sheaders);
    }

    fn verify(self: *ElfLinker, file: *const elf.Elf64) void {
        if (self.mutElf.header.type != .ET_REL or file.header.type != .ET_REL) {
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
        self.mutElf.header.type = self.args.output_type;
        if (self.mutElf.header.type == .ET_EXEC) {
            header.phentsize = 56;
            header.phnum = if (self.mutElf.pheaders) |ph| @intCast(ph.items.len) else 0;
            header.phoff = 64;
        }
        header.shoff = shoff + header.phnum * header.phentsize;
        header.shnum = shnum;
        header.shstrndx = shnum - 1;
    }

    fn addInterpSection(self: *ElfLinker) !void {
        if (self.args.dynamic_linker == null) return;
        const dynamic_linker = self.args.dynamic_linker.?;
        const sections = &self.mutElf.sections;
        var data = try self.allocator.alloc(u8, dynamic_linker.len + 1);
        @memcpy(data[0..dynamic_linker.len], dynamic_linker);
        data[dynamic_linker.len] = 0;
        const interp = elf.Section{
            .name = ".interp",
            .type = .SHT_PROGBITS,
            .flags = 0b010,
            .addr = 0,
            .data = data,
            .link = 0,
            .info = 0,
            .addralign = 0x1,
            .entsize = 0,
            .relocations = null,

            .allocator = self.allocator,
        };
        try sections.insert(0, interp);
    }

    pub fn deinit(self: *const ElfLinker) void {
        for (self.out.sections) |section| {
            self.allocator.free(section.data);
            if (section.name.len > 4 and std.mem.eql(u8, section.name[0..5], ".rela") and !std.mem.eql(u8, section.name, ".rela.dyn")) {
                self.allocator.free(section.name);
            }
            if (section.relocations) |rela| {
                self.allocator.free(rela);
            }
        }
        if (self.out.pheaders) |pheaders| {
            self.allocator.free(pheaders);
        }
        self.allocator.free(self.out.sections);
        self.allocator.free(self.out.symbols);
        self.allocator.free(self.out.sheaders);
    }
};
