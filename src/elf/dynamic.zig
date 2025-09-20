const std = @import("std");

pub const Dynamic = struct {
    tag: DTypes,
    un: union(enum) {
        val: u64,
        ptr: usize,
    },
};

pub const DTypes = enum(u32) {
    DT_NULL = 0,
    DT_NEEDED = 1, // d_val
    DT_PLTRELSZ = 2, // d_val
    DT_PLTGOT = 3, // d_ptr
    DT_HASH = 4, // d_ptr
    DT_STRTAB = 5, // d_ptr
    DT_SYMTAB = 6, // d_ptr
    DT_RELA = 7, // d_ptr
    DT_RELASZ = 8, // d_val
    DT_RELAENT = 9, // d_val
    DT_STRSZ = 10, // d_val
    DT_SYMENT = 11, // d_val
    DT_INIT = 12, // d_ptr
    DT_FINI = 13, // d_ptr
    DT_SONAME = 14, // d_val
    DT_RPATH = 15, // d_val
    DT_SYMBOLIC = 16, // ignored
    DT_REL = 17, // d_ptr
    DT_RELSZ = 18, // d_val
    DT_RELENT = 19, // d_val
    DT_PLTREL = 20, // d_val
    DT_DEBUG = 21, // d_ptr
    DT_TEXTREL = 22, // ignored
    DT_JMPREL = 23, // d_ptr
    DT_BIN_NOW = 24, // ignored
    DT_LOPROC = 0x70000000,
    DT_HIPROC = 0x7fffffff,
};

const HashTable = struct {
    nbucket: u32,
    nchain: u32,
    buckets: []u32,
    chains: []u32,
};
