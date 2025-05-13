const std = @import("std");

const headerNew = @import("header.zig").parse;
const sheaderNew = @import("sheader.zig").parse;
const sectionNew = @import("sections.zig").parse;
const updateSection = @import("relocations.zig").updateSection;
const symbolNew = @import("symbols.zig").parse;

const elf = @import("elf");

pub fn new(allocator: std.mem.Allocator, path: *[]const u8) !elf.Elf64 {
    const file = std.fs.cwd().openFile(path.*, .{}) catch |err| {
        std.debug.print("Error {s}: Failed to open '{s}'\n", .{ @errorName(err), path });
        std.process.exit(1);
    };
    defer file.close();

    const stat = try file.stat();
    const filebuffer = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(filebuffer);

    const fileHeader = try headerNew(allocator, filebuffer);
    const sheaders = try sheaderNew(allocator, filebuffer, fileHeader);
    const all_sections = try sectionNew(allocator, filebuffer, fileHeader, sheaders);
    defer allocator.free(all_sections);

    defer all_sections[fileHeader.shstrndx].deinit();

    var sections = std.ArrayList(elf.Section).init(allocator);
    defer sections.deinit();

    var special_section_count: usize = 0;
    var symtab_index: usize = undefined;
    var rela_indexes = std.ArrayList([2]usize).init(allocator);
    defer rela_indexes.deinit();

    for (sheaders, 0..) |sheader, i| {
        try switch (sheader.type) {
            .SHT_SYMTAB => symtab_index = i,
            .SHT_STRTAB => {},
            .SHT_RELA => rela_indexes.append([2]usize{ i, special_section_count }),
            else => {
                try sections.append(all_sections[i]);
                continue;
            },
        };
        special_section_count += 1;
    }
    const symbols = try symbolNew(
        allocator,
        fileHeader,
        sheaders,
        all_sections,
        symtab_index,
    );

    for (rela_indexes.items) |rela_index| {
        const rela_section = all_sections[rela_index[0]];
        defer rela_section.deinit();
        try updateSection(
            allocator,
            fileHeader,
            &sections.items[rela_section.info - rela_index[1]],
            rela_section,
        );
    }

    return elf.Elf64{
        .header = fileHeader,
        .pheaders = null,
        .sheaders = sheaders,
        .symbols = symbols,
        .sections = try sections.toOwnedSlice(),

        .allocator = allocator,
    };
}
