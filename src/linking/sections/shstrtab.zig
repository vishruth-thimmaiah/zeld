const std = @import("std");
const ElfLinker = @import("../linker.zig").ElfLinker;
const ElfSection = @import("../../parser/sections.zig").ElfSection;

pub fn buildShstrtab(linker: *ElfLinker) !void {
    var data = std.ArrayList(u8).init(linker.allocator);
    defer data.deinit();
    
    for (linker.mutElf.sections.items) |section| {
        try data.appendSlice(section.name);
        try data.append(0);
    }
    // TODO: set offset, link, etc
    const shstrtab = ElfSection {
        .name = ".shstrtab",
        .type = 3,
        .flags = 0,
        .addr = 0,
        .link = 0,
        .info = 0,
        .addralign = 1,
        .data = try data.toOwnedSlice(),
        .relocations = null,

        .allocator = linker.allocator,
    };
    try linker.mutElf.sections.append(shstrtab);
}
