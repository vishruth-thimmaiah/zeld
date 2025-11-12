const std = @import("std");
const elf = @import("elf");
const linker = @import("linker.zig");

pub fn addGotSection(self: *linker.ElfLinker, rela: []elf.Relocation) !void {
    const got = try self.allocator.alloc(u8, 0x8 * rela.len);
    @memset(got, 0);

    try self.mutElf.sections.append(self.allocator, .{
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
}

pub fn addPltSection(self: *linker.ElfLinker, plt_count: usize) !elf.Dynamic {
    const plt = try self.allocator.alloc(u8, 0x10 * plt_count);

    try self.mutElf.sections.append(self.allocator, .{
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
