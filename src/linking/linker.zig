const std = @import("std");
const parser = @import("../parser/elf.zig");
const helpers = @import("helpers.zig");

pub const ElfLinker = struct {
    files: []const parser.Elf64,
    out: parser.Elf64,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, files: []const parser.Elf64) ElfLinker {
        return ElfLinker{
            .files = files[1..],
            .out = files[0],

            .allocator = allocator,
        };
    }

    pub fn link(self: *const ElfLinker) !void {
        for (self.files) |file| {
            self.verify(file);

            try self.merge(file);
        }
    }
    fn verify(self: *const ElfLinker, file: parser.Elf64) void {
        if (self.out.header.type != 1 or file.header.type != 1) {
            std.debug.panic("File type is not yet supported", .{});
        }
    }

    fn merge(self: *const ElfLinker, file: parser.Elf64) !void {
        try self.mergeSections(file);
    }

    fn mergeSections(self: *const ElfLinker, file: parser.Elf64) !void {
        var self_sections = std.StringHashMap(usize).init(self.allocator);
        defer self_sections.deinit();

        for (self.out.sections, 0..) |*section, i| {
            try self_sections.put(section.name, i);
        }

        for (file.sections) |section| {
            if (self_sections.get(section.name)) |index| {
                std.debug.print("O:{s} {any}\n", .{self.out.sections[index].name, self.out.sections[index].data.len});
                self.out.sections[index].data = try self.mergeData(self.out.sections[index].data, section.data);
                std.debug.print("I: {any}\n", .{self.out.sections[index].data.len});
            } else {
                // TODO
                unreachable;
            }
        }
    }
    fn mergeData(self: *const ElfLinker, main: []const u8, other: []const u8) ![]const u8 {
        const data = &.{ main, other };
        const concated_data = try std.mem.concat(self.allocator, u8, data);
        defer self.allocator.free(concated_data);
        return concated_data;
    }
};
