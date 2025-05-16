const std = @import("std");

pub const Header = struct {
    class: u8,
    data: std.builtin.Endian,
    version: u8,
    osabi: u8,
    abiversion: u8,
    type: EType,
    machine: u16,
    file_version: u32,
    entry: u64,
    phoff: u64,
    shoff: u64,
    flags: u32,
    ehsize: u16,
    phentsize: u16,
    phnum: u16,
    shentsize: u16,
    shnum: u16,
    shstrndx: u16,
};

pub const EType = enum(u16) {
    ET_NONE = 0,
    ET_REL = 1,
    ET_EXEC = 2,
    ET_DYN = 3,
    ET_CORE = 4,
    ET_LOOS = 0xfe00,
    ET_HIOS = 0xfeff,
    ET_LOPROC = 0xff00,
    ET_HIPROC = 0xffff,
};

pub const SectionHeader = struct {
    name: u32,
    type: SHType,
    flags: u64,
    addr: u64,
    offset: u64,
    size: u64,
    link: u32,
    info: u32,
    addralign: u64,
    entsize: u64,
};

pub const SHType = enum(u32) {
    SHT_NULL,
    SHT_PROGBITS,
    SHT_SYMTAB,
    SHT_STRTAB,
    SHT_RELA,
    SHT_HASH,
    SHT_DYNAMIC,
    SHT_NOTE,
    SHT_NOBITS,
    SHT_REL,
    SHT_SHLIB,
    SHT_DYNSYM,
    _,
};

pub const ProgramHeader = struct {
    type: PHType,
    flags: u32,
    offset: u64,
    vaddr: u64,
    paddr: u64,
    filesz: u64,
    memsz: u64,
    align_: u64,

    pub fn setSize(self: *ProgramHeader, size: u64) void {
        self.filesz = size;
        self.memsz = size;
    }

    pub fn setAddr(self: *ProgramHeader, addr: u64) void {
        self.vaddr = addr;
        self.paddr = addr;
    }
};

pub const PHType = enum(u32) {
    PT_NULL = 0,
    PT_LOAD = 1,
    PT_DYNAMIC = 2,
    PT_INTERP = 3,
    PT_NOTE = 4,
    PT_SHLIB = 5,
    PT_PHDR = 6,
    PT_LOPROC = 0x70000000,
    PT_HIPROC = 0x7fffffff,
};
