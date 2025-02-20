const std = @import("std");

pub fn readInt(comptime T: type, bytes: []const u8, offset: usize, endian: std.builtin.Endian) T {
    const size = switch (T) {
        u8, i8 => 1,
        u16, i16 => 2,
        u32, i32 => 4,
        u64, i64 => 8,
        else => unreachable,
    };
    return std.mem.readInt(T, bytes[offset .. offset + size][0..size], endian);
}

pub fn getEndianness(magic: *const [16]u8) std.builtin.Endian {
    switch (magic[5]) {
        0x01 => return std.builtin.Endian.little,
        0x02 => return std.builtin.Endian.big,
        else => unreachable,
    }
}
