const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

pub fn generatePheaders(linker: *ElfLinker) !void {
    const sections = linker.mutElf.sections.items;
    linker.mutElf.pheaders = std.ArrayList(elf.ProgramHeader).init(linker.allocator);
    const pheaders = &linker.mutElf.pheaders.?;
    var offset: u64 = 64;
    var addr: u64 = elf.START_ADDR | 64;

    for (sections) |*section| {
        switch (section.type) {
            .SHT_PROGBITS => try generateLoad(pheaders, section, offset, &addr),
            .SHT_NOTE => try generateNote(pheaders, section, offset, &addr),
            .SHT_NOBITS => section.addr = addr,

            .SHT_NULL, .SHT_RELA, .SHT_STRTAB, .SHT_SYMTAB => {},
            // TODO
            else => unreachable,
        }
        offset += section.data.len;
        addr += section.data.len;
    }

    try generatePHDR(pheaders);

    for (pheaders.items[2..]) |*pheader| {
        pheader.setAddr(pheader.vaddr + pheaders.items.len * @sizeOf(elf.ProgramHeader));
        pheader.offset += pheaders.items.len * @sizeOf(elf.ProgramHeader);
    }

    for (sections) |*section| {
        if (section.flags & 0b010 == 0) continue;
        section.addr += pheaders.items.len * @sizeOf(elf.ProgramHeader);
    }
}

fn generatePHDR(pheaders: *std.ArrayList(elf.ProgramHeader)) !void {
    var sizeof = (pheaders.items.len + 2) * @sizeOf(elf.ProgramHeader);
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

    for (pheaders.items) |*pheader| {
        if (pheader.type != .PT_NOTE) break;
        sizeof += pheader.offset + pheader.memsz;
    }

    try pheaders.insert(0, phdr);

    const load = elf.ProgramHeader{
        .type = .PT_LOAD,
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

fn generateLoad(pheaders: *std.ArrayList(elf.ProgramHeader), section: *elf.Section, offset: u64, addr: *u64) !void {
    if (section.data.len == 0) return;
    addr.* += 0x1000;
    const load = elf.ProgramHeader{
        .type = .PT_LOAD,
        .flags = elf.helpers.shToPhFlags(section.flags),
        .offset = offset,
        .vaddr = addr.*,
        .paddr = addr.*,
        .filesz = section.data.len,
        .memsz = section.data.len,
        .align_ = 0x1000,
    };

    section.addr = load.vaddr;

    try pheaders.append(load);
}

fn generateNote(pheaders: *std.ArrayList(elf.ProgramHeader), section: *elf.Section, offset: u64, addr: *u64) !void {
    const note = elf.ProgramHeader{
        .type = .PT_NOTE,
        .flags = elf.helpers.shToPhFlags(section.flags),
        .offset = offset,
        .vaddr = addr.*,
        .paddr = addr.*,
        .filesz = section.data.len,
        .memsz = section.data.len,
        .align_ = 0x8,
    };

    section.addr = note.vaddr;

    try pheaders.append(note);
}
