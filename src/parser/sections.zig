const std = @import("std");

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
    entsize: u64,
    relocations: ?[]ElfRelocations,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, bytes: []const u8, header: ElfHeader, sheaders: []ElfSectionHeader) ![]ElfSection {
        const string_section = sheaders[header.shstrndx];

        var sections = try std.ArrayList(ElfSection).initCapacity(allocator, sheaders.len);
        defer sections.deinit();
        for (sheaders) |sheader| {
            if (sheader.name == 0) {
                continue;
            }
            const name = try getSectionName(sheader.name, bytes, string_section);
            const section = ElfSection{
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
            try sections.append(section);
        }
        return sections.toOwnedSlice();
    }

    pub fn deinit(self: *const ElfSection) void {
        self.allocator.free(self.name);
        self.allocator.free(self.data);
    }

    fn getSectionName(idx: u32, bytes: []const u8, string_header: ElfSectionHeader) ![]const u8 {
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
