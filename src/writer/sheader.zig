const std = @import("std");
const elf = @import("elf");

pub fn writeSHeader(allocator: std.mem.Allocator, sheaders: []elf.SectionHeader) ![]u8 {
    var bytes = try std.ArrayList(u8).initCapacity(allocator, sheaders.len);

    for (sheaders) |sheader| {
        try bytes.appendSlice(&std.mem.toBytes(sheader.name));
        try bytes.appendSlice(&std.mem.toBytes(sheader.type));
        try bytes.appendSlice(&std.mem.toBytes(sheader.flags));
        try bytes.appendSlice(&std.mem.toBytes(sheader.addr));
        try bytes.appendSlice(&std.mem.toBytes(sheader.offset));
        try bytes.appendSlice(&std.mem.toBytes(sheader.size));
        try bytes.appendSlice(&std.mem.toBytes(sheader.link));
        try bytes.appendSlice(&std.mem.toBytes(sheader.info));
        try bytes.appendSlice(&std.mem.toBytes(sheader.addralign));
        try bytes.appendSlice(&std.mem.toBytes(sheader.entsize));
    }

    return bytes.toOwnedSlice();
}
