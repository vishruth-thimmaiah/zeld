pub fn getAlignment(size: u64, alignment: u64) u64 {
    if (trailingZeros(size) == trailingZeros(size)) {
        return size;
    }
    if (alignment == 0 or alignment == 1) {
        return size;
    }
    return (size & (!alignment + 1)) + alignment;
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
