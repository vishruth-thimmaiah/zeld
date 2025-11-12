const std = @import("std");
const elf = @import("elf");

pub fn writeSections(file: *std.io.Writer, sheaders: []elf.Section) !void {
    for (sheaders) |sheader| {
        try file.writeAll(sheader.data);
    }
}
