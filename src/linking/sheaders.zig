const std = @import("std");

const elf = @import("elf");

pub fn buildSHeaders(
    allocator: std.mem.Allocator,
    sections: []const elf.Section,
    shstrtab_names: std.StringHashMap(u32),
    header: *elf.Header,
) ![]elf.SectionHeader {
    var sheaders = std.ArrayList(elf.SectionHeader).init(allocator);
    defer sheaders.deinit();

    try sheaders.append(std.mem.zeroes(elf.SectionHeader));

    var offset: usize = 64 + header.phnum * header.phentsize;

    for (sections) |section| {
        const sheader = elf.SectionHeader{
            .name = shstrtab_names.get(section.name) orelse 0,
            .type = section.type,
            .addr = if (section.flags & 0b010 != 0) elf.START_ADDR | offset else 0,
            .size = section.data.len,
            .link = section.link,
            .info = section.info,
            .flags = section.flags,
            .offset = offset,
            .addralign = section.addralign,
            .entsize = section.entsize,
        };
        if (std.mem.eql(u8, section.name, ".text")) {
            header.entry = sheader.addr;
        }
        try sheaders.append(sheader);
        offset += section.data.len;
    }

    return sheaders.toOwnedSlice();
}
