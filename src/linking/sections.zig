const std = @import("std");
const parser = @import("parser");
const ElfLinker = @import("linker.zig").ElfLinker;
const helpers = @import("helpers.zig");

pub fn mergeSections(linker: *ElfLinker, file: parser.Elf64) !std.StringHashMap(usize) {
    var section_map = std.StringHashMap(usize).init(linker.allocator);

    for (linker.mutElf.sections.items, 0..) |*section, i| {
        try section_map.put(section.name, i);
    }

    for (file.sections) |
        section,
    | {
        if (section_map.get(section.name)) |index| {
            const original_section = &linker.mutElf.sections.items[index];
            const alignment = helpers.getAlignment(original_section.data.len, original_section.addralign);
            original_section.data = try mergeData(linker, original_section.data, section.data, alignment);
            original_section.relocations = try mergeRelas(linker, original_section.relocations, section.relocations, alignment);
        } else {
            try linker.mutElf.sections.append(section);
            try section_map.put(section.name, linker.mutElf.sections.items.len - 1);
        }
    }
    return section_map;
}

fn mergeData(linker: *const ElfLinker, main: []const u8, other: []const u8, alignment: u64) ![]const u8 {
    defer linker.allocator.free(main);
    var concated_data = try linker.allocator.alloc(u8, other.len + alignment);
    @memcpy(concated_data[0..main.len], main);
    @memset(concated_data[main.len..alignment], 0xFF);
    @memcpy(concated_data[alignment..], other);
    return concated_data;
}

fn mergeRelas(
    linker: *const ElfLinker,
    main: ?[]parser.ElfRelocations,
    other: ?[]parser.ElfRelocations,
    alignment: u64,
) !?[]parser.ElfRelocations {
    if (main == null and other == null) return null;

    if (other) |_| {
        for (other.?) |*rela| {
            rela.offset += alignment;
        }
    }

    if (main == null or other == null) return main orelse try linker.allocator.dupe(parser.ElfRelocations, other.?);

    defer linker.allocator.free(main.?);

    const relas = &.{ main.?, other.? };
    const concated_relas = try std.mem.concat(linker.allocator, parser.ElfRelocations, relas);
    return concated_relas;
}
