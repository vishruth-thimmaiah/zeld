const std = @import("std");

const ElfLinker = @import("../linker.zig").ElfLinker;
const parser = @import("parser");
const ElfSection = parser.ElfSection;
const ElfRelocation = parser.ElfRelocations;

pub fn addRelocationSections(self: *ElfLinker) !void {
    const sections = &self.mutElf.sections.items;
    const len = sections.len - 1;
    for (0..sections.len) |count| {
        const section = sections.*[count];
        if (section.relocations) |relocations| {
            const relocSection = try buildRelocationSection(
                self.allocator,
                relocations,
                section.name,
                len,
                count,
            );
            try self.mutElf.sections.append(relocSection);
        }
    }
}

fn buildRelocationSection(
    allocator: std.mem.Allocator,
    relocations: []const ElfRelocation,
    name: []const u8,
    sh_size: usize,
    sh_info: usize,
) !ElfSection {
    var data = try std.ArrayList(u8).initCapacity(allocator, relocations.len * 24);
    defer data.deinit();

    for (relocations) |reloc| {
        var offset: [8]u8 = undefined;
        std.mem.writeInt(u64, &offset, reloc.offset, std.builtin.Endian.little);
        var info: [8]u8 = undefined;
        std.mem.writeInt(u64, &info, reloc.info, std.builtin.Endian.little);
        var addend: [8]u8 = undefined;
        std.mem.writeInt(i64, &addend, reloc.addend, std.builtin.Endian.little);

        try data.appendSlice(&offset);
        try data.appendSlice(&info);
        try data.appendSlice(&addend);
    }

    const rela_name = try std.fmt.allocPrint(allocator, ".rela{s}", .{name});

    return ElfSection{
        .name = rela_name,
        .data = try data.toOwnedSlice(),
        .type = .SHT_RELA,
        .flags = 0,
        .addr = 0,
        .link = @intCast(sh_size),
        .info = @intCast(sh_info + 1),
        .addralign = 8,
        .relocations = null,
        .entsize = 24,

        .allocator = allocator,
    };
}
