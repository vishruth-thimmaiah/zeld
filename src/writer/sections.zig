const std = @import("std");
const elf = @import("elf");

pub fn writeSections(allocator: std.mem.Allocator, sheaders: []elf.Section) ![]u8 {
    var bytes = std.ArrayList(u8).init(allocator);

    for (sheaders) |sheader| {
        try bytes.appendSlice(sheader.data);
    }

    return bytes.toOwnedSlice();
}
