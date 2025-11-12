const std = @import("std");

fn err(comptime fmt: []const u8, args: anytype) noreturn {
    std.log.err(fmt, args);
    std.process.exit(1);
}

fn warn(comptime fmt: []const u8, args: anytype) void {
    std.log.warn(fmt, args);
}

pub fn handleError(e: anyerror) noreturn {
    switch (e) {
        error.MissingInput => err("Missing input files", .{}),
        error.MissingTarget => err("Missing target", .{}),
        error.NotElf => err("File is not an ELF file", .{}),
        else => |_| {
            err("Unknown error: {}", .{e});
            @errorReturnTrace();
        },
    }
}

pub fn handleWarning(e: anyerror) void {
    switch (e) {
        error.UnknownFlag => warn("Unknown flag", .{}),
        else => unreachable,
    }
}
