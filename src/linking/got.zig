const std = @import("std");
const elf = @import("elf");
const linker = @import("linker.zig");

pub fn addGotSection(self: *linker.ElfLinker, rela: []elf.Relocation) !void {
    const got = try self.allocator.alloc(u8, 0x8 * rela.len);
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
        .entsize = 0x8,
        .relocations = null,

        .allocator = self.allocator,
    });
}

pub fn updateGot(_: *linker.ElfLinker, got_plt: *elf.Section, dynamic_ndx: u64) !void {
    const got_plt_data: *[8]u8 = @constCast(got_plt.data[0..8]);

    std.mem.writeInt(u64, got_plt_data, dynamic_ndx, std.builtin.Endian.little);
}
