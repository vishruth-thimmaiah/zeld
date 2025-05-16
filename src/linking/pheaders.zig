const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

pub fn generatePheaders(linker: *ElfLinker) !void {
    const sections = linker.mutElf.sections.items;
    linker.mutElf.pheaders = std.ArrayList(elf.ProgramHeader).init(linker.allocator);
    const pheaders = &linker.mutElf.pheaders.?;
    var addr: u64 = 64;

    for (sections) |*section| {
        switch (section.type) {
            .SHT_PROGBITS => {
                try generateLoad(pheaders, section, addr);
            },
            .SHT_NOTE => {},
            .SHT_NOBITS => {},

            .SHT_NULL, .SHT_RELA, .SHT_STRTAB, .SHT_SYMTAB => {},
            // TODO
            else => unreachable,
        }
        addr += section.data.len;
    }

    try generatePHDR(pheaders);

    for (pheaders.items[2..]) |*pheader| {
        pheader.setAddr(pheader.vaddr + pheaders.items.len * @sizeOf(elf.ProgramHeader));
        pheader.offset += pheaders.items.len * @sizeOf(elf.ProgramHeader);
    }
}

fn generatePHDR(pheaders: *std.ArrayList(elf.ProgramHeader)) !void {
    const sizeof = (pheaders.items.len + 2) * @sizeOf(elf.ProgramHeader);
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
    try pheaders.insert(0, phdr);

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
    try pheaders.insert(1, load);
}

fn generateLoad(pheaders: *std.ArrayList(elf.ProgramHeader), section: *elf.Section, addr: u64) !void {
    if (section.data.len == 0) return;
    const load = elf.ProgramHeader{
        .type = elf.PHType.PT_LOAD,
        .flags = 0b101,
        .offset = addr,
        .vaddr = elf.START_ADDR | addr,
        .paddr = elf.START_ADDR | addr,
        .filesz = section.data.len,
        .memsz = section.data.len,
        .align_ = 0x1000,
    };

    try pheaders.append(load);
}
