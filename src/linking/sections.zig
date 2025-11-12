const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

pub fn mergeSections(linker: *ElfLinker, file: *const elf.Elf64) !std.StringHashMap(usize) {
    var section_map = std.StringHashMap(usize).init(linker.allocator);
    const sections = &linker.mutElf.sections;

    for (sections.items, 0..) |*section, i| {
        try section_map.put(section.name, i);
    }

    for (file.sections) |*section| {
        if (section_map.get(section.name)) |index| {
            const original_section = &sections.items[index];
            const alignment = elf.helpers.getAlignment(original_section.data.len, original_section.addralign);
            original_section.data = try mergeData(linker, original_section.data, section.data, alignment);
            original_section.relocations = try mergeRelas(linker, original_section.relocations, section.relocations, alignment);
        } else {
            try sections.append(linker.allocator, section.*);
            // FIXME: temporary solution for double free when appending a section
            const last = &sections.items[sections.items.len - 1];
            last.data = try linker.allocator.dupe(u8, section.data);
            if (last.relocations) |r| last.relocations = try linker.allocator.dupe(elf.Relocation, r);
            try section_map.put(section.name, linker.mutElf.sections.items.len - 1);
        }
    }
    return section_map;
}

fn mergeData(linker: *const ElfLinker, main: []const u8, other: []const u8, alignment: u64) ![]u8 {
    defer linker.allocator.free(main);
    var concated_data = try linker.allocator.alloc(u8, other.len + alignment);
    @memcpy(concated_data[0..main.len], main);
    @memset(concated_data[main.len..alignment], 0xFF);
    @memcpy(concated_data[alignment..], other);
    return concated_data;
}

fn mergeRelas(
    linker: *const ElfLinker,
    main: ?[]elf.Relocation,
    other: ?[]elf.Relocation,
    alignment: u64,
) !?[]elf.Relocation {
    if (main == null and other == null) return null;

    if (other) |o| {
        for (o) |*rela| {
            rela.offset += alignment;
        }
    }

    if (main == null or other == null) return main orelse try linker.allocator.dupe(elf.Relocation, other.?);

    defer linker.allocator.free(main.?);

    const relas = &.{ main.?, other.? };
    const concated_relas = try std.mem.concat(linker.allocator, elf.Relocation, relas);
    return concated_relas;
}

pub fn organizeSections(linker: *ElfLinker) !void {
    std.sort.heap(elf.Section, linker.mutElf.sections.items, {}, struct {
        fn lessThan(_: void, a: elf.Section, b: elf.Section) bool {
            const a_order = elf.helpers.sectionSortOrder(a);
            const b_order = elf.helpers.sectionSortOrder(b);
            return a_order < b_order;
        }
    }.lessThan);
}
