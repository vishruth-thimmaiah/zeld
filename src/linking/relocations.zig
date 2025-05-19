const std = @import("std");

const ElfLinker = @import("linker.zig").ElfLinker;
const elf = @import("elf");
const Section = elf.Section;
const Relocation = elf.Relocation;

pub fn addRelocationSections(self: *ElfLinker) !void {
    const sections = &self.mutElf.sections.items;
    const len = sections.len - 1;

    var rela_indexes = std.ArrayList(struct { Section, usize }).init(self.allocator);
    defer rela_indexes.deinit();

    var rela_count: u32 = 0;

    for (0..sections.len) |count| {
        const section = sections.*[count];
        if (section.relocations) |relocations| {
            const relocSection = try buildRelocationSection(
                self.allocator,
                relocations,
                section.name,
                len + 1,
                count + rela_count,
            );
            try rela_indexes.append(.{ relocSection, count + rela_count + 1 });
            rela_count += 1;
        }
    }

    for (rela_indexes.items) |relainfo| {
        const idx = relainfo[1];
        var rela = relainfo[0];
        rela.link += rela_count + 1;
        try self.mutElf.sections.insert(idx, rela);
    }
}

fn buildRelocationSection(
    allocator: std.mem.Allocator,
    relocations: []const Relocation,
    name: []const u8,
    sh_size: usize,
    sh_info: usize,
) !Section {
    var data = try std.ArrayList(u8).initCapacity(allocator, relocations.len * 24);
    defer data.deinit();

    for (relocations) |reloc| {
        var offset: [8]u8 = undefined;
        std.mem.writeInt(u64, &offset, reloc.offset, std.builtin.Endian.little);
        var info: [8]u8 = undefined;
        std.mem.writeInt(u64, &info, reloc.info, std.builtin.Endian.little);
        var addend: [8]u8 = undefined;
        std.mem.writeInt(i64, &addend, reloc.addend, std.builtin.Endian.little);

        try data.appendSlice(&offset);
        try data.appendSlice(&info);
        try data.appendSlice(&addend);
    }

    const rela_name = try std.fmt.allocPrint(allocator, ".rela{s}", .{name});

    return Section{
        .name = rela_name,
        .data = try data.toOwnedSlice(),
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

                // TODO: try to do this in place
                const new_data = try linker.mutElf.allocator.dupe(u8, section.data);

                switch (reloc.get_type()) {
                    .R_X86_64_32S => {
                        const value = sum(i32, symbol.value, reloc.addend, 0);
                        std.mem.writeInt(i32, new_data[reloc.offset..][0..4], value, std.builtin.Endian.little);
                    },
                    .R_X86_64_PC32 => {
                        const value = sum(i32, symbol.value, reloc.addend, section.addr + reloc.offset);
                        std.mem.writeInt(i32, new_data[reloc.offset..][0..4], value, std.builtin.Endian.little);
                    },
                    else => undefined,
                }
                linker.allocator.free(section.data);
                section.data = new_data;
            }
        }
    }
}

// S: symbol.value
// A: reloc.addend
// P: reloc.offset
fn sum(comptime T: type, s: anytype, a: anytype, p: anytype) T {
    return @as(T, @intCast(s)) + @as(T, @intCast(a)) - @as(T, @intCast(p));
}
