const std = @import("std");
const utils = @import("utils.zig");

const elf = @import("elf");

pub fn parse(allocator: std.mem.Allocator, header: elf.Header, section: elf.Section) ![]elf.Relocation {
    var relocations = try std.ArrayList(elf.Relocation).initCapacity(allocator, section.data.len / 24);
    defer relocations.deinit(allocator);

    for (0..section.data.len / section.entsize) |i| {
        const offset = i * section.entsize;
        const rela = elf.Relocation{
            .offset = utils.readInt(u64, section.data, offset, header.data),
            .info = utils.readInt(u64, section.data, offset + 8, header.data),
            .addend = utils.readInt(i64, section.data, offset + 16, header.data),
        };
        try relocations.append(allocator, rela);
    }
    return try relocations.toOwnedSlice(allocator);
}

pub fn updateSection(allocator: std.mem.Allocator, header: elf.Header, section: *elf.Section, rela_section: elf.Section) !void {
    const relas = try parse(allocator, header, rela_section);
    section.relocations = relas;
}
