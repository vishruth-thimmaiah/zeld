const std = @import("std");

pub fn getAlignment(size: u64, alignment: u64) u64 {
    if (trailingZeros(size) == trailingZeros(alignment)) {
        return size;
    }
    if (alignment == 0 or alignment == 1) {
        return size;
    }
    return (size & (~alignment + 1)) + alignment;
}

pub fn trailingZeros(input: u64) u64 {
    const value: u64 = input & -%input;
    var count: u64 = 64;

    if (value != 0) count -%= 1;
    if ((value & 0xFFFFFFFF) != 0) count -%= 32;
    if ((value & 0x0000FFFF) != 0) count -%= 16;
    if ((value & 0x00FF00FF) != 0) count -%= 8;
    if ((value & 0x0F0F0F0F) != 0) count -%= 4;
    if ((value & 0x33333333) != 0) count -%= 2;
    if ((value & 0x55555555) != 0) count -%= 1;
    return count;
}

pub fn sectionSortOrder(name: []const u8) u8 {
    if (name.len == 0) {
        return 0;
    } else if (std.mem.eql(u8, name, ".interp")) {
        return 1;
    } else if (std.mem.startsWith(u8, name, ".note")) {
        return 2;
    } else if (std.mem.eql(u8, name, ".text")) {
        return 3;
    } else if (std.mem.eql(u8, name, ".rodata")) {
        return 4;
    } else if (std.mem.eql(u8, name, ".data")) {
        return 5;
    } else if (std.mem.eql(u8, name, ".bss")) {
        return 6;
    } else if (std.mem.eql(u8, name, ".dynamic")) {
        return 7;
    } else if (std.mem.startsWith(u8, name, ".dyn")) {
        return 8;
    } else if (std.mem.startsWith(u8, name, ".rela") or std.mem.startsWith(u8, name, ".rel")) {
        return 9;
    } else if (std.mem.eql(u8, name, ".symtab")) {
        return 10;
    } else if (std.mem.eql(u8, name, ".strtab")) {
        return 11;
    } else if (std.mem.eql(u8, name, ".shstrtab")) {
        return 12;
    } else if (std.mem.startsWith(u8, name, ".debug")) {
        return 13;
    } else {
        return 99;
    }
}
