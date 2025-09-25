const std = @import("std");
const Section = @import("sections.zig").Section;

pub const Symbol = struct {
    name: []const u8, // Pointer is 32 bits.
    info: u8,
    other: u8,
    shndx: STNdx,
    value: u64,
    size: u64,

    allocator: std.mem.Allocator,

    pub fn get_bind(self: Symbol) STBind {
        return @enumFromInt(self.info >> 4);
    }

    pub fn get_type(self: Symbol) STType {
        return @enumFromInt(self.info & 0xf);
    }

    pub fn set_bind(self: *Symbol, bind: STBind) void {
        self.info = (@intFromEnum(bind) << 4) | @intFromEnum(self.get_type());
    }

    pub fn set_type(self: *Symbol, ty: STType) void {
        self.info = @intCast((@intFromEnum(self.get_bind()) << 4) | @intFromEnum(ty));
    }

    pub fn getDisplayName(self: Symbol) []const u8 {
        if (self.name.len != 0) {
            return self.name;
        }
        if (self.shndx == .section) {
            return self.shndx.section;
        }
        return "";
    }

    pub fn deinit(self: *const Symbol) void {
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

pub const STNdx = union(enum(usize)) {
    SHN_UNDEF = 0,
    // SHN_LORESERVE = 0xff00,
    SHN_LOPROC = 0xff00,
    SHN_HIPROC = 0xff1f,
    SHN_ABS = 0xfff1,
    SHN_COMMON = 0xfff2,
    SHN_HIRESERVE = 0xffff,
    section: []const u8,

    pub fn fromInt(value: u16, sections: ?[]Section) STNdx {
        if (sections == null) return STNdx.SHN_UNDEF;
        return switch (value) {
            0 => STNdx.SHN_UNDEF,
            0xff00 => STNdx.SHN_LOPROC,
            0xff1f => STNdx.SHN_HIPROC,
            0xfff1 => STNdx.SHN_ABS,
            0xfff2 => STNdx.SHN_COMMON,
            0xffff => STNdx.SHN_HIRESERVE,
            else => STNdx{ .section = sections.?[value - 1].name },
        };
    }

    pub fn toInt(self: STNdx, sections: []Section) u16 {
        return switch (self) {
            STNdx.SHN_UNDEF => 0,
            STNdx.SHN_LOPROC => 0xff00,
            STNdx.SHN_HIPROC => 0xff1f,
            STNdx.SHN_ABS => 0xfff1,
            STNdx.SHN_COMMON => 0xfff2,
            STNdx.SHN_HIRESERVE => 0xffff,
            STNdx.section => |value| {
                for (sections, 0..) |section, i| {
                    if (std.mem.eql(u8, section.name, value)) {
                        return @intCast(i);
                    }
                }
                unreachable;
            },
        };
    }

    pub fn toIntFromMap(self: STNdx, section_map: std.StringHashMap(usize)) u16 {
        return switch (self) {
            STNdx.SHN_UNDEF => 0,
            STNdx.SHN_LOPROC => 0xff00,
            STNdx.SHN_HIPROC => 0xff1f,
            STNdx.SHN_ABS => 0xfff1,
            STNdx.SHN_COMMON => 0xfff2,
            STNdx.SHN_HIRESERVE => 0xffff,
            STNdx.section => |value| @intCast(section_map.get(value).?),
        };
    }

    pub fn isSpecial(self: STNdx) bool {
        return switch (self) {
            STNdx.section => false,
            else => true,
        };
    }
};
