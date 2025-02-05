const std = @import("std");

const ElfLinker = @import("../linker.zig").ElfLinker;
const ElfSection = @import("parser").ElfSection;

pub fn buildShstrtab(linker: *ElfLinker) !std.StringHashMap(u32) {
    var data = std.ArrayList(u8).init(linker.allocator);
    defer data.deinit();
    try data.append(0);

    var names = std.StringHashMap(u32).init(linker.allocator);

    for (linker.mutElf.sections.items) |section| {
        if (section.relocations != null) {
            continue;
        }
        if (section.type == 4) {
            try names.put(section.name[5..], @intCast(data.items.len + 5));
        }
        try names.put(section.name, @intCast(data.items.len));
        try data.appendSlice(section.name);
        try data.append(0);
    }
    try names.put(".shstrtab", @intCast(data.items.len));
    try data.appendSlice(".shstrtab\x00");

    const shstrtab = ElfSection{
        .name = ".shstrtab",
        .type = 3,
        .flags = 0,
        .addr = 0,
        .link = 0,
        .info = 0,
        .addralign = 1,
        .data = try data.toOwnedSlice(),
        .relocations = null,
        .entsize = 0,

        .allocator = linker.allocator,
    };
    try linker.mutElf.sections.append(shstrtab);

    return names;
}
