const std = @import("std");
const elf = @import("elf.zig");

pub fn getAlignment(size: u64, alignment: u64) u64 {
    if (alignment == 0) return size; // No alignment required
    return (size + alignment - 1) & ~(alignment - 1);
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

pub fn sectionSortOrder(section: elf.Section) u8 {
    if (section.name.len == 0) {
        return 0;
    } else if (std.mem.eql(u8, section.name, ".interp")) {
        return 1;
    } else if (std.mem.startsWith(u8, section.name, ".note")) {
        return 2;
    } else if (section.flags == 0b010 and section.type != .SHT_PROGBITS) {
        return 3;
    } else if (section.flags & 0b100 != 0) {
        return 4;
    } else if (section.flags == 0b010) {
        return 5;
    } else if (section.flags & 0b001 != 0) {
        return 6;
    } else {
        return 99;
    }
}

pub fn shToPhFlags(sh_flags: u64) u32 {
    var ph_flags: u32 = 0;

    // Write
    if (sh_flags & 0b001 != 0) {
        ph_flags |= 0b010;
    }
    // Allocate
    if (sh_flags & 0b010 != 0) {
        ph_flags |= 0b100;
    }
    // Execute
    if (sh_flags & 0b100 != 0) {
        ph_flags |= 0b001;
    }

    return ph_flags;
}
