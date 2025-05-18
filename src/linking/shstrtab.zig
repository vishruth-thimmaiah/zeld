const std = @import("std");

const ElfLinker = @import("linker.zig").ElfLinker;
const elf = @import("elf");

pub fn buildShstrtab(linker: *ElfLinker) !std.StringHashMap(u32) {
    var data = std.ArrayList(u8).init(linker.allocator);
    defer data.deinit();
    try data.append(0);

    var names = std.StringHashMap(u32).init(linker.allocator);

    for (linker.mutElf.sections.items) |section| {
        if (section.relocations != null and linker.args.output_type == .ET_REL) {
            try data.appendSlice(section.name);
            try data.append(0);
            continue;
        }
        if (section.type == .SHT_RELA and linker.args.output_type == .ET_REL) {
            try names.put(section.name[5..], @intCast(data.items.len + 5));
        }
        try names.put(section.name, @intCast(data.items.len));
        try data.appendSlice(section.name);
        try data.append(0);
    }
    try names.put(".shstrtab", @intCast(data.items.len));
    try data.appendSlice(".shstrtab\x00");

    const shstrtab = elf.Section{
        .name = ".shstrtab",
        .type = .SHT_STRTAB,
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
