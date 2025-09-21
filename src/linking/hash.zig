const std = @import("std");
const elf = @import("elf");
const linker = @import("linker.zig");

pub fn buildHashTable(self: *linker.ElfLinker, dynsym: []elf.Symbol) ![2]elf.Dynamic {
    if (dynsym.len == 0) {
        return [_]elf.Dynamic{
            .{ .tag = .DT_HASH, .un = .{ .ptr = undefined } },
            .{ .tag = .DT_NULL, .un = .{ .ptr = 0 } },
        };
    }

    const nchain: u32 = @intCast(dynsym.len + 1);
    const nbucket: u32 = @max(1, (nchain / 2));

    var buckets = try self.allocator.alloc(u32, nbucket);
    defer self.allocator.free(buckets);
    var chains = try self.allocator.alloc(u32, nchain);
    defer self.allocator.free(chains);

    @memset(buckets, 0);
    @memset(chains, 0);

    for (dynsym, 0..) |symbol, i| {
        if (symbol.name.len == 0) continue;

        const hash = symHash(symbol.name);
        const bucket_idx = hash % nbucket;

        chains[i] = buckets[bucket_idx];
        buckets[bucket_idx] = @intCast(i + 1);
    }

    var hash_data = std.ArrayList(u8).init(self.allocator);
    defer hash_data.deinit();

    try hash_data.appendSlice(std.mem.asBytes(&nbucket));
    try hash_data.appendSlice(std.mem.asBytes(&nchain));

    for (buckets) |bucket| {
        try hash_data.appendSlice(std.mem.asBytes(&bucket));
    }

    for (chains) |chain| {
        try hash_data.appendSlice(std.mem.asBytes(&chain));
    }

    try self.mutElf.sections.append(.{
        .name = ".hash",
        .type = .SHT_HASH,
        .flags = 0b010,
        .addr = 0,
        .data = try hash_data.toOwnedSlice(),
        .link = 0,
        .info = 0,
        .addralign = 0x4,
        .entsize = 4,
        .relocations = null,
        .allocator = self.allocator,
    });

    return [_]elf.Dynamic{
        .{ .tag = .DT_HASH, .un = .{ .ptr = undefined } },
        .{ .tag = .DT_NULL, .un = .{ .ptr = 0 } },
    };
}

// https://en.wikipedia.org/wiki/PJW_hash_function
fn symHash(name: []const u8) u32 {
    var hash: u32 = 0;
    var high: u32 = 0;

    for (name) |c| {
        hash = (hash << 4) + c;
        high = hash & 0xf0000000;
        if (high != 0) {
            hash ^= high >> 24;
        }
        hash &= ~high;
    }
    return hash;
}
