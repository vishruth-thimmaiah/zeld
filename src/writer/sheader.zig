const std = @import("std");
const elf = @import("elf");

const little = std.builtin.Endian.little;

pub fn writeSHeader(file: *std.io.Writer, sheaders: []elf.SectionHeader) !void {
    for (sheaders) |sheader| {
        try file.writeInt(u32, sheader.name, little);
        try file.writeInt(u32, @intFromEnum(sheader.type), little);
        try file.writeInt(u64, sheader.flags, little);
        try file.writeInt(u64, sheader.addr, little);
        try file.writeInt(u64, sheader.offset, little);
        try file.writeInt(u64, sheader.size, little);
        try file.writeInt(u32, sheader.link, little);
        try file.writeInt(u32, sheader.info, little);
        try file.writeInt(u64, sheader.addralign, little);
        try file.writeInt(u64, sheader.entsize, little);
    }
}
