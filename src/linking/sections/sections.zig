const std = @import("std");

const ElfLinker = @import("../linker.zig").ElfLinker;
const parser = @import("parser");
const ElfRelocations = parser.ElfRelocations;
const helpers = @import("../helpers.zig");

pub const buildShstrtab = @import("shstrtab.zig").buildShstrtab;
pub const addRelocationSections = @import("relocations.zig").addRelocationSections;

pub fn sectionReferences(linker: *ElfLinker, file: parser.Elf64) ![]?usize {
    var self_sections = std.StringHashMap(usize).init(linker.allocator);
    defer self_sections.deinit();

    for (linker.mutElf.sections.items, 0..) |*section, i| {
        try self_sections.put(section.name, i);
    }

    var referenced_sections = try linker.allocator.alloc(?usize, file.sections.len);

    for (file.sections, 0..) |section, i| {
        if (self_sections.get(section.name)) |index| {
            referenced_sections[i] = index;
        } else {
            referenced_sections[i] = null;
        }
    }
    return referenced_sections;
}

pub fn mergeSections(linker: *ElfLinker, file: parser.Elf64, refs: []?usize) !void {
    for (refs, 0..) |ref, idx| {
        const section = file.sections[idx];
        if (ref) |index| {
            const original_section = &linker.mutElf.sections.items[index];
            const alignment = helpers.getAlignment(original_section.data.len, original_section.addralign);
            original_section.data = try mergeData(linker, original_section.data, section.data, alignment);
            original_section.relocations = try mergeRelas(linker, original_section.relocations, section.relocations, alignment);
        } else {
            try linker.mutElf.sections.append(section);
        }
    }
}
fn mergeData(linker: *const ElfLinker, main: []const u8, other: []const u8, alignment: u64) ![]const u8 {
    defer linker.allocator.free(main);
    var concated_data = try linker.allocator.alloc(u8, other.len + alignment);
    @memcpy(concated_data[0..main.len], main);
    @memset(concated_data[main.len..alignment], 0xFF);
    @memcpy(concated_data[alignment..], other);
    return concated_data;
}

fn mergeRelas(linker: *const ElfLinker, main: ?[]ElfRelocations, other: ?[]ElfRelocations, alignment: u64) !?[]ElfRelocations {
    if (main == null and other == null) return null;

    if (other) |_| {
        for (other.?) |*rela| {
            rela.offset += alignment;
        }
    }

    if (main == null or other == null) return main orelse try linker.allocator.dupe(ElfRelocations, other.?);

    defer linker.allocator.free(main.?);

    const relas = &.{ main.?, other.? };
    const concated_relas = try std.mem.concat(linker.allocator, ElfRelocations, relas);
    return concated_relas;
}
