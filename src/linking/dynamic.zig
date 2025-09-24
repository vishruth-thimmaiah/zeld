const std = @import("std");
const elf = @import("elf");
const linker = @import("linker.zig");
const symbols = @import("symbols.zig");
const got = @import("got.zig");
const hash = @import("hash.zig");
const relocs = @import("relocations.zig");

fn getDynstr(self: *linker.ElfLinker, dynsym: []u8) !struct { []elf.Dynamic, usize } {
    var shared_lib_string = try std.ArrayList(u8).initCapacity(self.allocator, dynsym.len + 1);
    defer shared_lib_string.deinit();
    try shared_lib_string.append(0);
    try shared_lib_string.appendSlice(dynsym);
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

fn getDynsym(self: *linker.ElfLinker, rela: []elf.Relocation) !struct { [3]elf.Dynamic, []u8 } {
    var dynsym = std.ArrayList(elf.Symbol).init(self.allocator);
    defer dynsym.deinit();

    var dynstr_string = std.ArrayList(u8).init(self.allocator);
    defer dynstr_string.deinit();

    var dynsym_string = try std.ArrayList(u8).initCapacity(self.allocator, 0x18 * (rela.len + 1));
    defer dynsym_string.deinit();
    try dynsym_string.appendNTimes(0, 0x18);

    for (rela) |*reloc| {
        const symbol = self.mutElf.symbols.items[reloc.get_symbol()];
        try dynsym.append(symbol);
        reloc.set_symbol(dynsym.items.len);
        symbols.symbolToData(symbol, std.mem.toBytes(@as(u32, @intCast(dynsym.items.len + 1))), null, &dynsym_string) catch unreachable;
        try dynstr_string.appendSlice(symbol.name);
        try dynstr_string.append(0);
    }

    const hash_info = try hash.buildHashTable(self, try dynsym.toOwnedSlice());

    try self.mutElf.sections.append(.{
        .name = ".dynsym",
        .type = .SHT_DYNSYM,
        .flags = 0b010,
        .addr = 0,
        .data = try dynsym_string.toOwnedSlice(),
        .link = 0,
        .info = @intCast(dynsym.items.len + 1),
        .addralign = 0x1,
        .entsize = 0x18,
        .relocations = null,

        .allocator = self.allocator,
    });

    return .{ [_]elf.Dynamic{
        .{ .tag = .DT_SYMTAB, .un = .{ .ptr = undefined } },
        .{
            .tag = .DT_SYMENT,
            .un = .{ .val = 0x18 * (dynsym.items.len + 1) },
        },
        hash_info,
    }, try dynstr_string.toOwnedSlice() };
}

fn buildRelaTable(self: *linker.ElfLinker) !struct { [3]elf.Dynamic, []elf.Relocation } {
    var dynrela = std.ArrayList(elf.Relocation).init(self.allocator);
    defer dynrela.deinit();

    for (self.mutElf.sections.items) |*section| {
        if (section.relocations) |relocations| {
            for (relocations) |reloc| {
                switch (reloc.get_type()) {
                    .R_X86_64_GOTPCREL, .R_X86_64_GOTPCRELX => {
                        var new_reloc = reloc;
                        new_reloc.set_type(.R_X86_64_GLOB_DAT);
                        try dynrela.append(new_reloc);
                    },
                    else => {},
                }
            }
        }
    }
    const reloc_data: []u8 = try self.allocator.alloc(u8, 0x18 * dynrela.items.len);

    try self.mutElf.sections.append(.{
        .name = ".rela.dyn",
        .type = .SHT_RELA,
        .flags = 0b010,
        .addr = 0,
        .data = reloc_data,
        .link = 0,
        .info = 0,
        .addralign = 0x8,
        .entsize = 0x18,
        .relocations = null,

        .allocator = self.allocator,
    });

    return .{
        [3]elf.Dynamic{ .{
            .tag = .DT_RELA,
            .un = .{ .ptr = undefined },
        }, .{
            .tag = .DT_RELASZ,
            .un = .{ .val = @intCast(dynrela.items.len * 0x18) },
        }, .{
            .tag = .DT_RELAENT,
            .un = .{ .val = 0x18 },
        } },
        try dynrela.toOwnedSlice(),
    };
}

pub fn createDynamicSection(self: *linker.ElfLinker) !?struct { []elf.Dynamic, []elf.Relocation } {
    if (self.args.dynamic_linker == null) return null;

    var entries = std.ArrayList(elf.Dynamic).init(self.allocator);
    defer entries.deinit();

    const rela_info = try buildRelaTable(self);
    try entries.appendSlice(&rela_info[0]);
    const dynsym_info = try getDynsym(self, rela_info[1]);
    try entries.appendSlice(&dynsym_info[0]);
    try got.addGotSection(self, rela_info[1]);
    const needed = try getDynstr(self, dynsym_info[1]);
    defer self.allocator.free(needed[0]);
    try entries.appendSlice(needed[0]);

    try entries.append(.{
        .tag = .DT_NULL,
        .un = .{ .ptr = 0 },
    });

    const dynamic = elf.Section{
        .name = ".dynamic",
        .type = .SHT_DYNAMIC,
        .flags = 0b011,
        .addr = 0,
        .data = try self.allocator.alloc(u8, 0x10 * entries.items.len),
        .link = undefined,
        .info = 0,
        .addralign = 0x1,
        .entsize = 0x10,
        .relocations = null,

        .allocator = self.allocator,
    };

    try self.mutElf.sections.append(dynamic);

    return .{
        try entries.toOwnedSlice(),
        rela_info[1],
    };
}

pub fn updateDynamicSection(self: *linker.ElfLinker, dyn: ?struct { []elf.Dynamic, []elf.Relocation }) !void {
    if (dyn == null) return;
    const dyn_fields = dyn.?[0];
    const dyn_relocs = dyn.?[1];
    defer self.allocator.free(dyn_fields);

    var dyn_section: *elf.Section = undefined;
    var dynstr: *elf.Section = undefined;
    var dynsym: *elf.Section = undefined;
    var got_plt: *elf.Section = undefined;
    var hash_section: *elf.Section = undefined;
    var rela_dyn: *elf.Section = undefined;
    var dynstr_ndx: u32 = 0;
    var dynsym_ndx: u32 = 0;

    for (self.mutElf.sections.items, 1..) |*section, i| {
        if (section.type == .SHT_DYNAMIC) {
            dyn_section = section;
        } else if (section.type == .SHT_DYNSYM) {
            dynsym = section;
            dynsym_ndx = @intCast(i);
        } else if (section.type == .SHT_PROGBITS and std.mem.eql(u8, section.name, ".got.plt")) {
            got_plt = section;
        } else if (std.mem.eql(u8, section.name, ".got")) {
            relocs.RelocationType.got_idx = section;
        } else if (std.mem.eql(u8, section.name, ".dynstr")) {
            dynstr = section;
            dynstr_ndx = @intCast(i);
        } else if (section.type == .SHT_HASH) {
            hash_section = section;
        } else if (section.type == .SHT_RELA) {
            rela_dyn = section;
        }
    }

    var dynstr_data = std.ArrayList(u8).init(self.allocator);
    defer dynstr_data.deinit();

    try got.updateGot(self, got_plt, dyn_section.addr);
    @memcpy(rela_dyn.data[0 .. 0x18 * dyn_relocs.len], @as([]const u8, @ptrCast(dyn_relocs)));

    for (dyn_fields, 0..) |*d, i| {
        switch (d.tag) {
            .DT_STRTAB => d.un.ptr = dynstr.addr,
            .DT_SYMTAB => d.un.ptr = dynsym.addr,
            .DT_RELA => d.un.ptr = rela_dyn.addr,
            .DT_HASH => d.un.ptr = hash_section.addr,
            else => {},
        }
        @memcpy(dyn_section.data[i * 0x10 ..][0..0x10], &dynamicToBytes(d.*));
    }
    dynsym.link = dynstr_ndx;
    rela_dyn.link = dynsym_ndx;
    dyn_section.link = dynstr_ndx;
    hash_section.link = dynsym_ndx;
}

fn dynamicToBytes(dyn: elf.Dynamic) [16]u8 {
    const raw: u128 = @as(u128, @intFromEnum(dyn.tag)) | switch (dyn.un) {
        .val => @as(u128, dyn.un.val),
        .ptr => @as(u128, dyn.un.ptr),
    } << 64;
    return std.mem.asBytes(&raw).*;
}
