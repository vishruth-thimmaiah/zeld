const std = @import("std");

const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

pub fn buildSHeaders(
    linker: *ElfLinker,
    shstrtab_names: std.StringHashMap(u32),
) ![]elf.SectionHeader {
    var sheaders: std.ArrayList(elf.SectionHeader) = .empty;
    defer sheaders.deinit(linker.allocator);

    const header = &linker.mutElf.header;
    const sections = linker.mutElf.sections.items;

    try sheaders.append(linker.allocator, std.mem.zeroes(elf.SectionHeader));

    var offset: usize = 64 + header.phnum * header.phentsize;

    for (sections) |section| {
        const sheader = elf.SectionHeader{
            .name = shstrtab_names.get(section.name) orelse 0,
            .type = section.type,
            .addr = section.addr,
            .size = section.data.len,
            .link = section.link,
            .info = section.info,
            .flags = section.flags,
            .offset = offset,
            .addralign = section.addralign,
            .entsize = section.entsize,
        };
        try sheaders.append(linker.allocator, sheader);
        offset += section.data.len;
    }

    return try sheaders.toOwnedSlice(linker.allocator);
}
