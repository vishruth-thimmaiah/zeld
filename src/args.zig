const std = @import("std");
const elf = @import("elf");
const linker = @import("linker");
const errors = @import("errors.zig");

pub const Args = struct {
    rel_inputs: [][]const u8,
    output: []const u8,
    linker_args: linker.LinkerArgs,

    allocator: std.mem.Allocator,

    pub fn parse(allocator: std.mem.Allocator) !Args {
        var args = try std.process.argsWithAllocator(allocator);
        defer args.deinit();

        var rel_inputs = std.ArrayList([]const u8).init(allocator);
        defer rel_inputs.deinit();

        var dyn_inputs = std.ArrayList([]const u8).init(allocator);
        defer dyn_inputs.deinit();

        var results: Args = .{
            .rel_inputs = undefined,
            .output = "a.out",
            .linker_args = .{
                .output_type = .ET_EXEC,
                .dynamic_linker = null,
                .shared_libs = undefined,
            },

            .allocator = allocator,
        };

        _ = args.skip();

        while (args.next()) |next| {
            if (streql(next, "-o", "--output")) {
                if (args.next()) |output| {
                    results.output = output;
                    continue;
                }
                return error.MissingTarget;
            } else if (streql(next, "-r", "--relocatable")) {
                results.linker_args.output_type = .ET_REL;
            } else if (streql(next, null, "-dynamic-linker")) {
                if (args.next()) |dy_linker| {
                    results.linker_args.dynamic_linker = dy_linker;
                    continue;
                }
                return error.MissingInput;
            } else if (next[0] != '-') {
                switch (try classify_file(next)) {
                    .ET_REL => try rel_inputs.append(next),
                    .ET_DYN => try dyn_inputs.append(next),
                    else => return error.UnsupportedFileType,
                }
            } else {
                errors.handleWarning(error.UnknownFlag);
            }
        }

        if (rel_inputs.items.len == 0) {
            return error.MissingInput;
        }

        results.rel_inputs = try rel_inputs.toOwnedSlice();
        results.linker_args.shared_libs = try dyn_inputs.toOwnedSlice();

        return results;
    }

    pub fn deinit(self: *const Args) void {
        self.allocator.free(self.rel_inputs);
        self.allocator.free(self.linker_args.shared_libs);
    }
};

fn streql(arg: []const u8, short: ?[]const u8, long: []const u8) bool {
    if (short) |s| {
        return std.mem.eql(u8, arg, s) or std.mem.eql(u8, arg, long);
    }
    return std.mem.eql(u8, arg, long);
}

fn classify_file(path: []const u8) !elf.Header.Type {
    var buffer: [18]u8 = undefined;
    const data = try std.fs.cwd().readFile(path, &(&buffer).*);
    if (!std.mem.eql(u8, data[0..4], &elf.MAGIC_BYTES)) {
        return error.NotElf;
    }
    return @enumFromInt(std.mem.readInt(u16, data[16..18], std.builtin.Endian.little));
}
