const std = @import("std");
const elf = @import("elf");

pub fn writeHeader(writer: anytype, header: elf.Header) !void {
    try writer.writeAll(&elf.MAGIC_BYTES);
    try writer.writeByte(header.class);
    try writer.writeByte(if (header.data == std.builtin.Endian.little) 1 else 2);
    try writer.writeByte(header.version);
    try writer.writeByte(header.osabi);
    try writer.writeByte(header.abiversion);
    _ = try writer.splatByte(0, 16 - 9);
    try writer.writeInt(u16, @intFromEnum(header.type), header.data);
    try writer.writeInt(u16, header.machine, header.data);
    try writer.writeInt(u32, header.file_version, header.data);
    try writer.writeInt(u64, header.entry, header.data);
    try writer.writeInt(u64, header.phoff, header.data);
    try writer.writeInt(u64, header.shoff, header.data);
    try writer.writeInt(u32, header.flags, header.data);
    try writer.writeInt(u16, header.ehsize, header.data);
    try writer.writeInt(u16, header.phentsize, header.data);
    try writer.writeInt(u16, header.phnum, header.data);
    try writer.writeInt(u16, header.shentsize, header.data);
    try writer.writeInt(u16, header.shnum, header.data);
    try writer.writeInt(u16, header.shstrndx, header.data);
}
