const std = @import("std");

pub const Args = struct {
    inputs: [][]const u8,
    output: []const u8,

    allocator: std.mem.Allocator,

    pub fn parse(allocator: std.mem.Allocator) !Args {
        var args = try std.process.argsWithAllocator(allocator);
        defer args.deinit();

        var inputs = std.ArrayList([]const u8).init(allocator);
        defer inputs.deinit();

        var results: Args = undefined;
        results.output = "a.out";
        results.allocator = allocator;

        _ = args.skip();

        while (args.next()) |next| {
            if (streql(next, "-o", "--output")) {
                if (args.next()) |output| {
                    results.output = output;
                    continue;
                }
                return error.MissingOutput;
            } else {
                try inputs.append(next);
            }
        }

        if (inputs.items.len == 0) {
            return error.MissingInput;
        }

        results.inputs = try inputs.toOwnedSlice();
        return results;
    }

    pub fn deinit(self: *const Args) void {
        self.allocator.free(self.inputs);
    }
};

fn streql(arg: []const u8, short: []const u8, long: []const u8) bool {
    return std.mem.eql(u8, arg, short) or std.mem.eql(u8, arg, long);
}
