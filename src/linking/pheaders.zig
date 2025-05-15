const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

pub fn generatePheaders(linker: *ElfLinker) !void {
    const sections = linker.mutElf.sections.items;
    linker.mutElf.pheaders = std.ArrayList(elf.ProgramHeader).init(linker.allocator);
    const pheaders = &linker.mutElf.pheaders.?;
    _ = pheaders;

    var phdr_map = std.AutoHashMap(u96, usize).init(linker.allocator);
    defer phdr_map.deinit();

    for (sections) |*section| {
        switch (section.type) {
            .SHT_PROGBITS => {},
            .SHT_NOTE => {},
            .SHT_NOBITS => {},

            .SHT_NULL, .SHT_RELA, .SHT_STRTAB, .SHT_SYMTAB => {},
            // TODO
            else => unreachable,
        }
    }
}
