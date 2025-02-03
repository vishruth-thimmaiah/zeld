const std = @import("std");

const ElfLinker = @import("../linker.zig").ElfLinker;
const parser = @import("parser");
const ElfSection = parser.ElfSection;
const ElfRelocation = parser.ElfRelocations;

pub fn addRelocationSections(self: *ElfLinker) !void {
    var count: usize = 0;
    const sections = &self.mutElf.sections.items;
    while (count < sections.len) : (count += 1) {
        const section = sections.*[count];
        if (section.relocations) |relocations| {
            const relocSection = try buildRelocationSection(self.allocator, relocations, section.name);
            try self.mutElf.sections.append(relocSection);
        }
    }
}

fn buildRelocationSection(allocator: std.mem.Allocator, relocations: []const ElfRelocation, name: []const u8) !ElfSection {
    var data = try std.ArrayList(u8).initCapacity(allocator, relocations.len * 24);
    defer data.deinit();

    for (relocations) |reloc| {
        var offset: [8]u8 = undefined;
        std.mem.writeInt(u64, &offset, reloc.offset, std.builtin.Endian.little);
        var info: [8]u8 = undefined;
        std.mem.writeInt(u64, &info, reloc.info, std.builtin.Endian.little);
        var addend: [8]u8 = undefined;
        std.mem.writeInt(u64, &addend, reloc.addend, std.builtin.Endian.little);

        try data.appendSlice(&offset);
        try data.appendSlice(&info);
        try data.appendSlice(&addend);
    }

    const rela_name = try std.fmt.allocPrint(allocator, ".rela{s}", .{name});

    return ElfSection{
        .name = rela_name,
        .data = try data.toOwnedSlice(),
        .type = 4,
        .flags = 0,
        .addr = 0,
        .link = 0,
        .info = 0,
        .addralign = 8,
        .relocations = null,
        .entsize = 24,

        .allocator = allocator,
    };
}
