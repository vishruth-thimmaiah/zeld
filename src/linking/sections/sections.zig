const std = @import("std");

const ElfLinker = @import("../linker.zig").ElfLinker;
const parser = @import("parser");

pub const buildShstrtab = @import("shstrtab.zig").buildShstrtab;

pub fn mergeSections(linker: *const ElfLinker, file: parser.Elf64) !void {
    
    var self_sections = std.StringHashMap(usize).init(linker.allocator);
    defer self_sections.deinit();

    for (linker.mutElf.sections.items, 0..) |*section, i| {
        try self_sections.put(section.name, i);
    }

    for (file.sections) |section| {
        if (self_sections.get(section.name)) |index| {
            const original_data = linker.mutElf.sections.items[index].data;
            linker.mutElf.sections.items[index].data = try mergeData(linker, original_data, section.data);
        } else {
            // TODO
            unreachable;
        }
    }
}
fn mergeData(linker: *const ElfLinker, main: []const u8, other: []const u8) ![]const u8 {
    const data = &.{ main, other };
    const concated_data = try std.mem.concat(linker.allocator, u8, data);
    return concated_data;
}
