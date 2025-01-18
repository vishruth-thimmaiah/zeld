const std = @import("std");

const ElfLinker = @import("../linker.zig").ElfLinker;
const parser = @import("parser");
const ElfRelocations = parser.ElfRelocations;

pub const buildShstrtab = @import("shstrtab.zig").buildShstrtab;

pub fn mergeSections(linker: *ElfLinker, file: parser.Elf64) !void {
    
    var self_sections = std.StringHashMap(usize).init(linker.allocator);
    defer self_sections.deinit();

    for (linker.mutElf.sections.items, 0..) |*section, i| {
        try self_sections.put(section.name, i);
    }

    for (file.sections) |section| {
        if (self_sections.get(section.name)) |index| {
            const original_section = linker.mutElf.sections.items[index];
            linker.mutElf.sections.items[index].data = try mergeData(linker, original_section.data, section.data);
            linker.mutElf.sections.items[index].relocations = try mergeRelas(linker, original_section.relocations, section.relocations);
        } else {
            try linker.mutElf.sections.append(section);
        }
    }
}
fn mergeData(linker: *const ElfLinker, main: []const u8, other: []const u8) ![]const u8 {
    const data = &.{ main, other };
    const concated_data = try std.mem.concat(linker.allocator, u8, data);
    return concated_data;
}

fn mergeRelas(linker: *const ElfLinker, main: ?[]ElfRelocations, other: ?[]ElfRelocations) !?[]ElfRelocations {
    if (main == null and other == null) return null;
    // FIXME: Avoid allocating a new array to avoid double freeing if possible
    if (main == null or other == null) return try linker.allocator.dupe(ElfRelocations, main orelse other.?);
    const relas = &.{ main.?, other.? };
    const concated_relas = try std.mem.concat(linker.allocator, ElfRelocations, relas);
    return concated_relas;
}
