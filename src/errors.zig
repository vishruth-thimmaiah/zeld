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
        error.Help => {
            std.debug.print("Usage: zeld [options] <input files>\n", .{});
            std.debug.print("  Options:\n", .{});
            std.debug.print("    -o, --output <file>    Specify the output file\n", .{});
            std.debug.print("    -r, --relocatable      Create a relocatable file\n", .{});
            std.debug.print("    -dynamic-linker <file> Specify the dynamic linker\n", .{});
            std.debug.print("    -h, --help             Display this help message\n", .{});
            std.process.exit(0);
        },
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
