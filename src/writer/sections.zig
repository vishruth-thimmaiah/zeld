const std = @import("std");
const parser = @import("parser");

pub fn writeSections(allocator: std.mem.Allocator, sheaders: []parser.ElfSection) ![]u8 {
    var bytes = std.ArrayList(u8).init(allocator);

    for (sheaders) |sheader| {
        try bytes.appendSlice(sheader.data);
    }

    return bytes.toOwnedSlice();
}
