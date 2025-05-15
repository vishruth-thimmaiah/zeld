const std = @import("std");

pub fn readInt(comptime T: type, bytes: []const u8, offset: usize, endian: std.builtin.Endian) T {
    const size = @sizeOf(T);
    switch (@typeInfo(T)) {
        .int => {
            return std.mem.readInt(T, bytes[offset .. offset + size][0..size], endian);
        },
        .@"enum" => {
            const int_type = std.meta.Int(.unsigned, @bitSizeOf(T));
            const a = std.mem.readInt(int_type, bytes[offset .. offset + size][0..size], endian);
            return @as(T, @enumFromInt(a));
        },
        else => unreachable,
    }
}

pub fn getEndianness(magic: *const [16]u8) std.builtin.Endian {
    switch (magic[5]) {
        0x01 => return std.builtin.Endian.little,
        0x02 => return std.builtin.Endian.big,
        else => unreachable,
    }
}
