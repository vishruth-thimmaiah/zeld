const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

pub fn generatePheaders(linker: *ElfLinker) !void {
    const sections = linker.mutElf.sections.items;
    linker.mutElf.pheaders = std.ArrayList(elf.ProgramHeader).init(linker.allocator);
    const pheaders = &linker.mutElf.pheaders.?;

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

    try generatePHDR(pheaders);
}

fn generatePHDR(pheaders: *std.ArrayList(elf.ProgramHeader)) !void {
    const sizeof = pheaders.items.len + 2 * @sizeOf(elf.ProgramHeader);
    const phdr = elf.ProgramHeader{
        .type = elf.PHType.PT_PHDR,
        .flags = 0b100,
        .offset = 0x40,
        .vaddr = elf.START_ADDR | 0x40,
        .paddr = elf.START_ADDR | 0x40,
        .filesz = sizeof,
        .memsz = sizeof,
        .align_ = 0x8,
    };
    try pheaders.append(phdr);

    const load = elf.ProgramHeader{
        .type = elf.PHType.PT_LOAD,
        .flags = 0b100,
        .offset = 0,
        .vaddr = elf.START_ADDR,
        .paddr = elf.START_ADDR,
        .filesz = sizeof + 64,
        .memsz = sizeof + 64,
        .align_ = 0x1000,
    };
    try pheaders.append(load);
}
