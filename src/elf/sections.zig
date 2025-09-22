const std = @import("std");

const SectionHeader = @import("header.zig");
const Relocation = @import("relocations.zig").Relocation;

pub const Section = struct {
    name: []const u8,
    type: SectionHeader.SHType,
    flags: u64,
    addr: u64,
    link: u32,
    info: u32,
    addralign: u64,
    data: []u8,
    entsize: u64,
    relocations: ?[]Relocation,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *const Section) void {
        if (self.relocations) |relas| {
            self.allocator.free(relas);
        }
        self.allocator.free(self.name);
        self.allocator.free(self.data);
    }
};
