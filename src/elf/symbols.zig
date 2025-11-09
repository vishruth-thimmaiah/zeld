const std = @import("std");
const Section = @import("sections.zig").Section;

pub const Symbol = struct {
    name: []const u8, // Pointer is 32 bits.
    info: u8,
    other: u8,
    shndx: Ndx,
    value: u64,
    size: u64,

    allocator: std.mem.Allocator,

    pub fn get_bind(self: Symbol) Bind {
        return @enumFromInt(self.info >> 4);
    }

    pub fn get_type(self: Symbol) Type {
        return @enumFromInt(self.info & 0xf);
    }

    pub fn set_bind(self: *Symbol, bind: Bind) void {
        self.info = (@intFromEnum(bind) << 4) | @intFromEnum(self.get_type());
    }

    pub fn set_type(self: *Symbol, ty: Type) void {
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

    pub const Bind = enum(usize) {
        STB_LOCAL = 0,
        STB_GLOBAL = 1,
        STB_WEAK = 2,
        STB_LOPROC = 13,
        STB_HIPROC = 15,
    };

    pub const Type = enum(usize) {
        STT_NOTYPE = 0,
        STT_OBJECT = 1,
        STT_FUNC = 2,
        STT_SECTION = 3,
        STT_FILE = 4,
        STT_LOPROC = 13,
        STT_HIPROC = 15,
    };

    pub const Ndx = union(enum(usize)) {
        SHN_UNDEF = 0,
        // SHN_LORESERVE = 0xff00,
        SHN_LOPROC = 0xff00,
        SHN_HIPROC = 0xff1f,
        SHN_ABS = 0xfff1,
        SHN_COMMON = 0xfff2,
        SHN_HIRESERVE = 0xffff,
        section: []const u8,

        pub fn fromInt(value: u16, sections: ?[]Section) Ndx {
            if (sections == null) return Ndx.SHN_UNDEF;
            return switch (value) {
                0 => Ndx.SHN_UNDEF,
                0xff00 => Ndx.SHN_LOPROC,
                0xff1f => Ndx.SHN_HIPROC,
                0xfff1 => Ndx.SHN_ABS,
                0xfff2 => Ndx.SHN_COMMON,
                0xffff => Ndx.SHN_HIRESERVE,
                else => Ndx{ .section = sections.?[value - 1].name },
            };
        }

        pub fn toInt(self: Ndx, sections: []Section) u16 {
            return switch (self) {
                Ndx.SHN_UNDEF => 0,
                Ndx.SHN_LOPROC => 0xff00,
                Ndx.SHN_HIPROC => 0xff1f,
                Ndx.SHN_ABS => 0xfff1,
                Ndx.SHN_COMMON => 0xfff2,
                Ndx.SHN_HIRESERVE => 0xffff,
                Ndx.section => |value| {
                    for (sections, 0..) |section, i| {
                        if (std.mem.eql(u8, section.name, value)) {
                            return @intCast(i);
                        }
                    }
                    unreachable;
                },
            };
        }

        pub fn toIntFromMap(self: Ndx, section_map: std.StringHashMap(usize)) u16 {
            return switch (self) {
                Ndx.SHN_UNDEF => 0,
                Ndx.SHN_LOPROC => 0xff00,
                Ndx.SHN_HIPROC => 0xff1f,
                Ndx.SHN_ABS => 0xfff1,
                Ndx.SHN_COMMON => 0xfff2,
                Ndx.SHN_HIRESERVE => 0xffff,
                Ndx.section => |value| @intCast(section_map.get(value).?),
            };
        }

        pub fn isSpecial(self: Ndx) bool {
            return switch (self) {
                Ndx.section => false,
                else => true,
            };
        }
    };
};
