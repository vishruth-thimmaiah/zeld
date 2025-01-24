const std = @import("std");
const parser = @import("parser");

pub fn writer(elf: parser.Elf64, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{.mode = 0o777});
    defer file.close();

    try file.writeAll(&parser.MAGIC_BYTES);
    _ = elf;
}
