const std = @import("std");
const parser = @import("parser");

pub fn writeHeader(header: parser.ElfHeader) ![64]u8 {
    var bytes: [64]u8 = undefined;
    bytes[0..4].* = parser.MAGIC_BYTES;
    bytes[4] = header.class;
    bytes[5] = if (header.data == std.builtin.Endian.little) 1 else 2;
    bytes[6] = header.version;
    bytes[7] = header.osabi;
    bytes[8] = header.abiversion;

    @memset(bytes[9..16], 0);

    bytes[16..18].* = std.mem.toBytes(header.type);
    bytes[18..20].* = std.mem.toBytes(header.machine);
    bytes[20..24].* = std.mem.toBytes(header.file_version);
    bytes[24..32].* = std.mem.toBytes(header.entry);
    bytes[32..40].* = std.mem.toBytes(header.phoff);
    bytes[40..48].* = std.mem.toBytes(header.shoff);
    bytes[48..52].* = std.mem.toBytes(header.flags);
    bytes[52..54].* = std.mem.toBytes(header.ehsize);
    bytes[54..56].* = std.mem.toBytes(header.phentsize);
    bytes[56..58].* = std.mem.toBytes(header.phnum);
    bytes[58..60].* = std.mem.toBytes(header.shentsize);
    bytes[60..62].* = std.mem.toBytes(header.shnum);
    bytes[62..64].* = std.mem.toBytes(header.shstrndx);

    return bytes;
}
