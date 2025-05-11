const std = @import("std");

const elf = @import("elf");

pub fn buildSHeaders(
    allocator: std.mem.Allocator,
    sections: []const elf.Section,
    shstrtab_names: std.StringHashMap(u32),
) ![]elf.SectionHeader {
    var sheaders = std.ArrayList(elf.SectionHeader).init(allocator);
    defer sheaders.deinit();

    try sheaders.append(std.mem.zeroes(elf.SectionHeader));

    var offset: usize = 64;

    for (sections) |section| {
        const header = elf.SectionHeader{
            // TODO: set name
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
        try sheaders.append(header);
        offset += section.data.len;
    }

    return sheaders.toOwnedSlice();
}
