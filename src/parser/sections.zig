const std = @import("std");

const elf = @import("elf");

pub fn parse(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header: elf.Header,
    sheaders: []elf.SectionHeader,
) ![]elf.Section {
    const string_section = sheaders[header.shstrndx];

    var sections = try allocator.alloc(elf.Section, sheaders.len);
    for (sheaders, 0..) |*sheader, i| {
        if (try parseSection(allocator, bytes, sheader, &string_section)) |section| {
            sections[i] = section;
        }
    }
    return sections;
}

pub fn parseSection(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    sheader: *const elf.SectionHeader,
    strings: ?*const elf.SectionHeader,
) !?elf.Section {
    if (sheader.name == 0) {
        return null;
    }
    const name = if (strings) |s| try getSectionName(sheader.name, bytes, s) else "";
    const section = elf.Section{
        .name = try allocator.dupe(u8, name),
        .type = sheader.type,
        .flags = sheader.flags,
        .addr = sheader.addr,
        .link = sheader.link,
        .info = sheader.info,
        .addralign = sheader.addralign,
        .data = try allocator.dupe(u8, bytes[sheader.offset .. sheader.offset + sheader.size]),
        .entsize = sheader.entsize,
        .relocations = null,

        .allocator = allocator,
    };
    return section;
}

fn getSectionName(idx: u32, bytes: []const u8, string_header: *const elf.SectionHeader) ![]const u8 {
    const start_offset = string_header.offset + idx;
    var end_offset = start_offset;

    while (true) {
        if (bytes[end_offset] == 0) {
            break;
        }
        end_offset += 1;
    }
    return bytes[start_offset..end_offset];
}
