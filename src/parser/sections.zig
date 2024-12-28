const std = @import("std");
const print = std.debug.print;

const ElfHeader = @import("header.zig").ElfHeader;
const ElfSectionHeader = @import("sheader.zig").SectionHeader;
const ElfRelocations = @import("relocations.zig").ElfRelocations;

pub const ElfSection = struct {
    name: []const u8,
    type: u32,
    flags: u64,
    addr: u64,
    link: u32,
    info: u32,
    addralign: u64,
    data: []const u8,
    relocations: []ElfRelocations,

    pub fn new(allocator: std.mem.Allocator, bytes: []const u8, header: ElfHeader, sheaders: []ElfSectionHeader) ![]ElfSection {
        const string_section = sheaders[header.shstrndx];

        var sections = try std.ArrayList(ElfSection).initCapacity(allocator, sheaders.len);
        defer sections.deinit();
        for (sheaders) |sheader| {
            if (sheader.name == 0) {
                continue;
            }
            const name = try getSectionName(allocator, sheader.name, bytes, string_section);
            defer allocator.free(name);
            var section = ElfSection{
                .name = name,
                .type = sheader.type,
                .flags = sheader.flags,
                .addr = sheader.addr,
                .link = sheader.link,
                .info = sheader.info,
                .addralign = sheader.addralign,
                .data = bytes[sheader.offset .. sheader.offset + sheader.size],
                .relocations = undefined
            };
            section.relocations = try ElfRelocations.new(allocator, header, section);
            defer allocator.free(section.relocations);
            std.debug.print("Symbol: {any}\n\n", .{section});
            try sections.append(section);
        }
        return sections.toOwnedSlice();
    }

    fn getSectionName(allocator: std.mem.Allocator, idx: u32, bytes: []const u8, string_header: ElfSectionHeader) ![]const u8 {
        var offset = string_header.offset + idx;

        var section_name = std.ArrayList(u8).init(allocator);
        defer section_name.deinit();

        while (true) {
            if (bytes[offset] == 0) {
                break;
            }
            try section_name.append(bytes[offset]);
            offset += 1;
        }
        return section_name.toOwnedSlice();
    }

    fn getSymbolName(idx: u32, bytes: []const u8, string_header: ElfSectionHeader) ![]const u8 {
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
};
