const std = @import("std");
const elf = @import("elf");

pub fn writePHeader(allocator: std.mem.Allocator, pheaders: []elf.ProgramHeader) ![]u8 {
    var bytes = try std.ArrayList(u8).initCapacity(allocator, pheaders.len);

    for (pheaders) |sheader| {
        try bytes.appendSlice(&std.mem.toBytes(sheader.type));
        try bytes.appendSlice(&std.mem.toBytes(sheader.flags));
        try bytes.appendSlice(&std.mem.toBytes(sheader.offset));
        try bytes.appendSlice(&std.mem.toBytes(sheader.vaddr));
        try bytes.appendSlice(&std.mem.toBytes(sheader.paddr));
        try bytes.appendSlice(&std.mem.toBytes(sheader.filesz));
        try bytes.appendSlice(&std.mem.toBytes(sheader.memsz));
        try bytes.appendSlice(&std.mem.toBytes(sheader.align_));
    }

    return bytes.toOwnedSlice();
}
