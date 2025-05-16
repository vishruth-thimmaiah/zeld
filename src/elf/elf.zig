const std = @import("std");

pub const MAGIC_BYTES = [4]u8{ 0x7F, 0x45, 0x4C, 0x46 };
pub const START_ADDR = 0x400000;

pub const Header = @import("header.zig").Header;
pub const EType = @import("header.zig").EType;

pub const ProgramHeader = @import("header.zig").ProgramHeader;
pub const PHType = @import("header.zig").PHType;

pub const SectionHeader = @import("header.zig").SectionHeader;
pub const SHType = @import("header.zig").SHType;

pub const Section = @import("sections.zig").Section;

pub const Relocation = @import("relocations.zig").Relocation;

pub const Symbol = @import("symbols.zig").Symbol;
pub const STBind = @import("symbols.zig").STBind;
pub const STType = @import("symbols.zig").STType;
pub const STNdx = @import("symbols.zig").STNdx;

pub const Elf64 = struct {
    header: Header,
    pheaders: ?[]ProgramHeader,
    sheaders: []SectionHeader,
    symbols: []Symbol,
    sections: []Section,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *const Elf64) void {
        for (self.symbols) |symbol| symbol.deinit();
        for (self.sections) |section| section.deinit();
        if (self.pheaders) |pheaders| self.allocator.free(pheaders);
        self.allocator.free(self.sheaders);
        self.allocator.free(self.symbols);
        self.allocator.free(self.sections);
    }
};
