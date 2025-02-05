const std = @import("std");

const parser = @import("parser");

pub fn buildSHeaders(
    allocator: std.mem.Allocator,
    sections: []const parser.ElfSection,
    shstrtab_names: std.StringHashMap(u32),
) ![]parser.ElfSectionHeader {
    var sheaders = std.ArrayList(parser.ElfSectionHeader).init(allocator);
    defer sheaders.deinit();

    try sheaders.append(std.mem.zeroes(parser.ElfSectionHeader));

    var offset: usize = 64;

    for (sections) |section| {
        const header = parser.ElfSectionHeader{
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
