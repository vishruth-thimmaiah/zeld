const ElfLinker = @import("../linker.zig").ElfLinker;
const parser = @import("../../parser/elf.zig");

const std = @import("std");

pub fn mergeSections(linker: *const ElfLinker, file: parser.Elf64) !void {
    var self_sections = std.StringHashMap(usize).init(linker.allocator);
    defer self_sections.deinit();

    for (linker.out.sections, 0..) |*section, i| {
        try self_sections.put(section.name, i);
    }

    for (file.sections) |section| {
        if (self_sections.get(section.name)) |index| {
            std.debug.print("O:{s} {any}\n", .{ linker.out.sections[index].name, linker.out.sections[index].data.len });
            linker.out.sections[index].data = try mergeData(linker, linker.out.sections[index].data, section.data);
            std.debug.print("I: {any}\n", .{linker.out.sections[index].data.len});
        } else {
            // TODO
            unreachable;
        }
    }
}
fn mergeData(linker: *const ElfLinker, main: []const u8, other: []const u8) ![]const u8 {
    const data = &.{ main, other };
    const concated_data = try std.mem.concat(linker.allocator, u8, data);
    defer linker.allocator.free(concated_data);
    return concated_data;
}
