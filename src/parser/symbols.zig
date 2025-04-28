const std = @import("std");
const utils = @import("utils.zig");

const ElfHeader = @import("header.zig").ElfHeader;
const ElfSectionHeader = @import("sheader.zig").SectionHeader;
const ElfSection = @import("sections.zig").ElfSection;

pub const ElfSymbol = struct {
    name: []const u8, // Pointer is 32 bits.
    info: u8,
    other: u8,
    shndx: u16,
    value: u64,
    size: u64,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, header: ElfHeader, sheaders: []ElfSectionHeader, sections: []ElfSection, symtab_index: usize) ![]ElfSymbol {
        var symbols = try std.ArrayList(ElfSymbol).initCapacity(allocator, sheaders.len);
        defer symbols.deinit();

        const symtab_header = sheaders[symtab_index];
        const symtab = sections[symtab_index];
        defer symtab.deinit();

        const string_section = sections[symtab.link];
        defer string_section.deinit();

        for (0..symtab_header.size / symtab_header.entsize) |i| {
            const offset = symtab_header.entsize * i;
            const name_offset = utils.readInt(u32, symtab.data, offset, header.data);
            const symbol = ElfSymbol{
                .name = try allocator.dupe(u8, getSymbolName(name_offset, string_section.data)),
                .info = utils.readInt(u8, symtab.data, offset + 4, header.data),
                .other = utils.readInt(u8, symtab.data, offset + 5, header.data),
                .shndx = utils.readInt(u16, symtab.data, offset + 6, header.data),
                .value = utils.readInt(u64, symtab.data, offset + 8, header.data),
                .size = utils.readInt(u64, symtab.data, offset + 16, header.data),

                .allocator = allocator,
            };

            try symbols.append(symbol);
        }

        return symbols.toOwnedSlice();
    }

    pub fn get_bind(self: ElfSymbol) STBind {
        return @enumFromInt(self.info >> 4);
    }

    pub fn get_type(self: ElfSymbol) STType {
        return @enumFromInt(self.info & 0xf);
    }

    fn getSymbolName(idx: u32, bytes: []const u8) []const u8 {
        var end_offset = idx;

        while (true) {
            if (bytes[end_offset] == 0) {
                break;
            }
            end_offset += 1;
        }

        return bytes[idx..end_offset];
    }

    pub fn deinit(self: *const ElfSymbol) void {
        self.allocator.free(self.name);
    }
};

pub const STBind = enum(usize) {
    STB_LOCAL = 0,
    STB_GLOBAL = 1,
    STB_WEAK = 2,
    STB_LOPROC = 13,
    STB_HIPROC = 15,
};

pub const STType = enum(usize) {
    STT_NOTYPE = 0,
    STT_OBJECT = 1,
    STT_FUNC = 2,
    STT_SECTION = 3,
    STT_FILE = 4,
    STT_LOPROC = 13,
    STT_HIPROC = 15,
};
