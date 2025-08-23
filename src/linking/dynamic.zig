const std = @import("std");
const elf = @import("elf");
const linker = @import("linker.zig");

fn getDynstr(self: *linker.ElfLinker) !struct { []elf.Dynamic, usize } {
    var shared_lib_string = std.ArrayList(u8).init(self.allocator);
    defer shared_lib_string.deinit();
    var needed = try self.allocator.alloc(elf.Dynamic, self.args.shared_libs.len + 2);

    for (self.args.shared_libs, 0..) |lib, i| {
        needed[i] = .{
            .tag = .DT_NEEDED,
            .un = .{ .val = shared_lib_string.items.len },
        };
        try shared_lib_string.appendSlice(lib);
        try shared_lib_string.append(0);
    }
    needed[needed.len - 2] = .{
        .tag = .DT_STRTAB,
        .un = .{ .ptr = undefined },
    };

    needed[needed.len - 1] = .{
        .tag = .DT_STRSZ,
        .un = .{ .val = shared_lib_string.items.len },
    };

    try self.mutElf.sections.append(.{
        .name = ".dynstr",
        .type = .SHT_STRTAB,
        .flags = 0b010,
        .addr = 0,
        .data = try shared_lib_string.toOwnedSlice(),
        .link = 0,
        .info = 0,
        .addralign = 0x1,
        .entsize = 0,
        .relocations = null,

        .allocator = self.allocator,
    });

    return .{ needed, self.mutElf.sections.items.len - 1 };
}

fn getDynsym(self: *linker.ElfLinker) ![2]elf.Dynamic {
    var dynsym = std.ArrayList(elf.Symbol).init(self.allocator);
    defer dynsym.deinit();

    var dynsym_string = try self.allocator.alloc(u8, 0x18 * (dynsym.items.len + 1));
    @memset(dynsym_string[dynsym.items.len..], 0);

    try self.mutElf.sections.append(.{
        .name = ".dynsym",
        .type = .SHT_DYNSYM,
        .flags = 0b010,
        .addr = 0,
        .data = dynsym_string,
        .link = 0,
        .info = @intCast(dynsym.items.len + 1),
        .addralign = 0x1,
        .entsize = 0x18,
        .relocations = null,

        .allocator = self.allocator,
    });

    return [_]elf.Dynamic{ .{
        .tag = .DT_SYMTAB,
        .un = .{ .ptr = undefined },
    }, .{
        .tag = .DT_SYMENT,
        .un = .{ .val = 0x18 * (dynsym.items.len + 1) },
    } };
}

pub fn createDynamicSection(self: *linker.ElfLinker) !?[]elf.Dynamic {
    if (self.args.dynamic_linker == null) return null;

    var entries = std.ArrayList(elf.Dynamic).init(self.allocator);
    defer entries.deinit();

    const needed = try getDynstr(self);
    defer self.allocator.free(needed[0]);
    try entries.appendSlice(needed[0]);
    try entries.appendSlice(&(try getDynsym(self)));

    try entries.append(.{
        .tag = .DT_NULL,
        .un = .{ .ptr = 0 },
    });

    const dynamic = elf.Section{
        .name = ".dynamic",
        .type = .SHT_DYNAMIC,
        .flags = 0b011,
        .addr = 0,
        .data = undefined,
        .link = undefined,
        .info = 0,
        .addralign = 0x1,
        .entsize = 0x10,
        .relocations = null,

        .allocator = self.allocator,
    };

    try self.mutElf.sections.append(dynamic);

    return try entries.toOwnedSlice();
}

pub fn updateDynamicSection(self: *linker.ElfLinker, dyn: ?[]elf.Dynamic) !void {
    if (dyn == null) return;
    defer self.allocator.free(dyn.?);

    var dyn_section: *elf.Section = undefined;
    var dynstr: *elf.Section = undefined;
    var dynsym: *elf.Section = undefined;
    var dynstr_ndx: u32 = 0;

    for (self.mutElf.sections.items, 1..) |*section, i| {
        if (section.type == .SHT_DYNAMIC) dyn_section = section //
        else if (section.type == .SHT_DYNSYM) dynsym = section //
        else if (std.mem.eql(u8, section.name, ".dynstr")) {
            dynstr = section;
            dynstr_ndx = @intCast(i);
        }
    }

    var dynstr_data = std.ArrayList(u8).init(self.allocator);
    defer dynstr_data.deinit();

    for (dyn.?) |*d| {
        switch (d.tag) {
            .DT_STRTAB => d.un.ptr = dynstr.addr,
            .DT_SYMTAB => d.un.ptr = dynsym.addr,
            else => {},
        }
        try dynstr_data.appendSlice(&dynamicToBytes(d.*));
    }
    dynsym.link = dynstr_ndx;
    dyn_section.link = dynstr_ndx;
    dyn_section.data = try dynstr_data.toOwnedSlice();
}

fn dynamicToBytes(dyn: elf.Dynamic) [16]u8 {
    const raw: u128 = @as(u128, @intFromEnum(dyn.tag)) | switch (dyn.un) {
        .val => @as(u128, dyn.un.val),
        .ptr => @as(u128, dyn.un.ptr),
    } << 64;
    return std.mem.asBytes(&raw).*;
}

// https://en.wikipedia.org/wiki/PJW_hash_function
fn symHash(name: []const u8) u32 {
    var hash: u32 = 0;
    var high: u32 = 0;

    for (name) |c| {
        hash = (hash << 4) + c;
        high = hash & 0xf0000000;
        if (high) {
            hash ^= high >> 24;
        }
        hash &= ~high;
    }
    return hash;
}
