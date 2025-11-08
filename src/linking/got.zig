const std = @import("std");
const elf = @import("elf");
const linker = @import("linker.zig");

pub fn addGotSection(self: *linker.ElfLinker, rela: []elf.Relocation, plt_size: usize) !void {
    const got = try self.allocator.alloc(u8, 0x8 * (rela.len + plt_size));
    @memset(got, 0);

    try self.mutElf.sections.append(.{
        .name = ".got",
        .type = .SHT_PROGBITS,
        .flags = 0b011,
        .addr = 0,
        .data = got,
        .link = 0,
        .info = 0,
        .addralign = 0x8,
        .entsize = 0x8,
        .relocations = null,

        .allocator = self.allocator,
    });

    try addGotPltSection(self, rela);
}

pub fn addGotPltSection(self: *linker.ElfLinker, rela: []elf.Relocation) !void {
    var gotPlt = try self.allocator.alloc(u8, 0x8 * (rela.len + 2));
    @memset(gotPlt[0x8..], 0);

    try self.mutElf.sections.append(.{
        .name = ".got.plt",
        .type = .SHT_PROGBITS,
        .flags = 0b011,
        .addr = 0,
        .data = gotPlt,
        .link = 0,
        .info = 0,
        .addralign = 0x8,
        .entsize = 0x10,
        .relocations = null,

        .allocator = self.allocator,
    });
}

pub fn updateGot(_: *linker.ElfLinker, got_plt: *elf.Section, dynamic_ndx: u64) !void {
    std.mem.writeInt(u64, got_plt.data[0..8], dynamic_ndx, std.builtin.Endian.little);
}

pub fn addPltSection(self: *linker.ElfLinker, plt_count: usize) !elf.Dynamic {
    const plt = try self.allocator.alloc(u8, 0x10 * plt_count);

    try self.mutElf.sections.append(.{
        .name = ".plt",
        .type = .SHT_PROGBITS,
        .flags = 0b110,
        .addr = 0,
        .data = plt,
        .link = 0,
        .info = 0,
        .addralign = 0x10,
        .entsize = 0x10,
        .relocations = null,

        .allocator = self.allocator,
    });

    return .{
        .tag = .DT_PLTGOT,
        .un = .{ .ptr = undefined },
    };
}
