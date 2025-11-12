const std = @import("std");
const elf = @import("elf");

const little = std.builtin.Endian.little;

pub fn writePHeader(file: *std.io.Writer, pheaders: []elf.ProgramHeader) !void {
    for (pheaders) |sheader| {
        try file.writeInt(u32, @intFromEnum(sheader.type), little);
        try file.writeInt(u32, sheader.flags, little);
        try file.writeInt(u64, sheader.offset, little);
        try file.writeInt(u64, sheader.vaddr, little);
        try file.writeInt(u64, sheader.paddr, little);
        try file.writeInt(u64, sheader.filesz, little);
        try file.writeInt(u64, sheader.memsz, little);
        try file.writeInt(u64, sheader.align_, little);
    }
}
