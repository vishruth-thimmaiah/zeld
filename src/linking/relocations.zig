const std = @import("std");

const ElfLinker = @import("linker.zig").ElfLinker;
const elf = @import("elf");
const Section = elf.Section;
const Relocation = elf.Relocation;

pub fn addRelocationSections(self: *ElfLinker) !void {
    const sections = self.mutElf.sections.items;
    const len = sections.len - 1;

    var rela_indexes: std.ArrayList(struct { Section, usize }) = .empty;
    defer rela_indexes.deinit(self.allocator);

    var rela_count: u32 = 0;

    for (sections, 0..) |*section, i| {
        if (section.relocations) |relocations| {
            const relocSection = try buildRelocationSection(
                self.allocator,
                relocations,
                section.name,
                len + 1,
                i + rela_count,
            );
            try rela_indexes.append(self.allocator, .{ relocSection, i + rela_count + 1 });
            rela_count += 1;
        }
    }

    for (rela_indexes.items) |relainfo| {
        const idx = relainfo[1];
        var rela = relainfo[0];
        rela.link += rela_count + 1;
        try self.mutElf.sections.insert(self.allocator, idx, rela);
    }
}

fn buildRelocationSection(
    allocator: std.mem.Allocator,
    relocations: []const Relocation,
    name: []const u8,
    sh_size: usize,
    sh_info: usize,
) !Section {
    var data: std.ArrayList(u8) = .empty;
    defer data.deinit(allocator);

    for (relocations) |reloc| {
        var offset: [8]u8 = undefined;
        std.mem.writeInt(u64, &offset, reloc.offset, std.builtin.Endian.little);
        var info: [8]u8 = undefined;
        std.mem.writeInt(u64, &info, reloc.info, std.builtin.Endian.little);
        var addend: [8]u8 = undefined;
        std.mem.writeInt(i64, &addend, reloc.addend, std.builtin.Endian.little);

        try data.appendSlice(allocator, &offset);
        try data.appendSlice(allocator, &info);
        try data.appendSlice(allocator, &addend);
    }

    const rela_name = try std.fmt.allocPrint(allocator, ".rela{s}", .{name});

    return Section{
        .name = rela_name,
        .data = try data.toOwnedSlice(allocator),
        .type = .SHT_RELA,
        .flags = 0,
        .addr = 0,
        .link = @intCast(sh_size),
        .info = @intCast(sh_info + 1),
        .addralign = 8,
        .relocations = null,
        .entsize = 24,

        .allocator = allocator,
    };
}

pub fn applyRelocations(linker: *ElfLinker) !void {
    const sections = linker.mutElf.sections.items;
    const symbols = linker.mutElf.symbols.items;

    for (sections) |*section| {
        if (section.relocations) |relocations| {
            for (relocations) |*reloc| {
                const symbol = symbols[reloc.get_symbol()];

                const rela_data = r: {
                    switch (reloc.get_type()) {
                        .R_X86_64_32, .R_X86_64_32S => break :r .{ RelocationType.ABSOLUTE, i32 },
                        .R_X86_64_PC32 => break :r .{ RelocationType.RELATIVE, i32 },
                        .R_X86_64_REX_GOTPCRELX => break :r .{ RelocationType.PCREL_RELAXABLE_REX, i32 },
                        .R_X86_64_GOTPCRELX => break :r .{ RelocationType.PCREL_RELAXABLE, i32 },
                        .R_X86_64_PLT32 => break :r .{ RelocationType.PLT, i32 },
                        else => std.debug.panic("Unsupported relocation type {s}", .{@tagName(reloc.get_type())}),
                    }
                };
                const rela_type = rela_data[0];
                const rela_size = rela_data[1];
                const new_addr = rela_type.resolve(rela_size, &symbol, section, reloc);
                std.mem.writeInt(
                    rela_size,
                    section.data[reloc.offset..][0..@sizeOf(rela_size)],
                    new_addr,
                    std.builtin.Endian.little,
                );
            }
        }
    }
}

const ENDBR64 = [4]u8{ 0xf3, 0x0f, 0x1e, 0xfa };
const BND_JMP = [3]u8{ 0xf2, 0xff, 0x25 };
const NOPL = [5]u8{ 0x0f, 0x1f, 0x44, 0x00, 0x00 };

pub const RelocationType = enum {
    ABSOLUTE,
    RELATIVE,
    PCREL,
    PCREL_RELAXABLE,
    PCREL_RELAXABLE_REX,
    PLT,
    NONE,

    pub var got_idx: *elf.Section = undefined;
    pub var plt_idx: *elf.Section = undefined;
    var plt_count: usize = 0;
    var got_count: usize = 0;

    fn resolve(
        self: RelocationType,
        T: type,
        symbol: *const elf.Symbol,
        section: *const elf.Section,
        reloc: *elf.Relocation,
    ) T {
        switch (self) {
            .ABSOLUTE => return @as(T, @intCast(symbol.value)) + @as(T, @intCast(reloc.addend)),
            .RELATIVE => return @as(T, @intCast(symbol.value)) + @as(T, @intCast(reloc.addend)) - @as(T, @intCast(section.addr + reloc.offset)),
            .PCREL, .PCREL_RELAXABLE, .PCREL_RELAXABLE_REX => {
                const abs = @as(T, @intCast(got_idx.addr + got_count * 0x8)) + @as(T, @intCast(reloc.addend));
                got_count += 1;
                return abs - @as(T, @intCast(section.addr + reloc.offset));
            },
            .PLT => {
                const plt_data = plt_idx.data;
                @memcpy(plt_data[plt_count * 0x10 ..][0x0..0x4], ENDBR64[0..]);
                @memcpy(plt_data[plt_count * 0x10 ..][0x4..0x7], BND_JMP[0..]);
                @memcpy(plt_data[plt_count * 0x10 ..][0xb..0x10], NOPL[0..]);

                const offset = @as(T, @intCast(got_idx.addr + got_count * 0x8)) - @as(T, @intCast(plt_idx.addr + plt_count * 0x10 + 0xb));
                std.mem.writeInt(
                    T,
                    plt_data[plt_count * 0x10 ..][0x7..0xb],
                    offset,
                    std.builtin.Endian.little,
                );

                const plt = @as(T, @intCast(plt_idx.addr + plt_count * 0x10)) + @as(T, @intCast(reloc.addend));

                got_count += 1;
                plt_count += 1;

                return plt - @as(T, @intCast(section.addr + reloc.offset));
            },
            .NONE => return 0,
        }
        return 0;
    }

    pub fn try_relax(self: RelocationType, symbol: *const elf.Symbol, reloc: *elf.Relocation, section: *const elf.Section) bool {
        switch (self) {
            .PCREL_RELAXABLE_REX => {
                if (symbol.get_type() == .STT_NOTYPE) return false;
                if (reloc.offset < 3) return false;

                const rex = section.data[reloc.offset - 3];
                const op = &section.data[reloc.offset - 2];
                const modrm = &section.data[reloc.offset - 1];

                if (rex != 0x48) return false;
                switch (op.*) {
                    0x8b => {
                        op.* = 0xc7;
                        modrm.* = (modrm.* >> 3) & 0x7 | 0xc0;
                        reloc.addend = 0;
                        reloc.set_type(.R_X86_64_32);
                        return true;
                    },
                    else => return false,
                }
            },
            .PCREL_RELAXABLE => return false,
            else => return false,
        }
        return false;
    }
};
