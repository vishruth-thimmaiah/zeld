const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

const SegmentArray = std.ArrayList(Segment);

const Segment = union(enum) {
    SEGMENT_START: struct { elf.ProgramHeader.Type, u32, u64, u64 },
    SEGMENT_END,
    SECTION: *elf.Section,

    fn addSingleSegment(allocator: std.mem.Allocator, segments: *SegmentArray, section: *elf.Section, offset: u64, type_: elf.ProgramHeader.Type, flags: u32, align_: u64) !void {
        try segments.append(allocator, .{ .SEGMENT_START = .{ type_, flags, align_, offset } });
        try segments.append(allocator, .{ .SECTION = section });
        try segments.append(allocator, .SEGMENT_END);
    }

    fn prependSingleSegment(allocator: std.mem.Allocator, segments: *SegmentArray, section: *elf.Section, offset: u64, type_: elf.ProgramHeader.Type, flags: u32, align_: u64) !void {
        try segments.insert(allocator, 0, .{ .SEGMENT_START = .{ type_, flags, align_, offset } });
        try segments.insert(allocator, 1, .{ .SECTION = section });
        try segments.insert(allocator, 2, .SEGMENT_END);
    }
};

fn SegmentBuilder(linker: *ElfLinker) !struct { []Segment, u32 } {
    const sections = linker.mutElf.sections.items;

    var segments: SegmentArray = .empty;
    var other_segments: SegmentArray = .empty;
    defer other_segments.deinit(linker.allocator);
    defer segments.deinit(linker.allocator);

    var counter: u32 = 0;
    var addr: u64 = elf.START_ADDR;
    var offset: u64 = 0x40;

    for (sections) |*section| {
        var flags: ?u32 = null;
        switch (section.flags) {
            0b110 => flags = 0b101,
            0b011 => flags = 0b110,
            0b010 => flags = 0b100,
            else => {},
        }
        if (flags) |flag| {
            const last = segments.getLastOrNull() orelse last: {
                counter += 1;
                try segments.append(linker.allocator, .{ .SEGMENT_START = .{ .PT_LOAD, flag, 0x1000, offset } });
                break :last segments.getLast();
            };
            if (last == .SECTION and last.SECTION.flags != section.flags) {
                counter += 1;
                addr += 0x1000;
                try segments.append(linker.allocator, .SEGMENT_END);
                try segments.append(linker.allocator, .{ .SEGMENT_START = .{ .PT_LOAD, flag, 0x1000, offset } });
            } else if (last == .SEGMENT_END) {
                counter += 1;
                addr += 0x1000;
                try segments.append(linker.allocator, .{ .SEGMENT_START = .{ .PT_LOAD, flag, 0x1000, offset } });
            }
            try segments.append(linker.allocator, .{ .SECTION = section });
        }

        if (std.mem.eql(u8, section.name, ".interp")) {
            try Segment.prependSingleSegment(linker.allocator, &segments, section, offset, .PT_INTERP, 0b100, 0x1);
            counter += 1;
        }
        if (section.type == .SHT_NOTE) {
            try Segment.addSingleSegment(linker.allocator, &other_segments, section, offset, .PT_NOTE, 0b100, 0x8);
            counter += 1;
        }
        if (section.type == .SHT_DYNAMIC) {
            try Segment.addSingleSegment(linker.allocator, &other_segments, section, offset, .PT_DYNAMIC, 0b101, 0x8);
            counter += 1;
        }

        section.addr = addr;
        addr += section.data.len;
        offset += section.data.len;
    }
    try segments.append(linker.allocator, .SEGMENT_END);

    try segments.appendSlice(linker.allocator, other_segments.items);

    for (sections) |*section| {
        section.addr += 0x40 + (counter + 1) * @sizeOf(elf.ProgramHeader);
    }

    // for (segments.items) |*segment| {
    //     switch (segment.*) {
    //         .SEGMENT_START => |start| std.debug.print("start: {any}\n", .{start}),
    //         .SEGMENT_END => std.debug.print("end\n", .{}),
    //         .SECTION => |section| std.debug.print("section: {s}\n", .{section.name}),
    //     }
    // }

    return .{ try segments.toOwnedSlice(linker.allocator), counter };
}

pub fn generatePheaders(linker: *ElfLinker) !void {
    const sb = try SegmentBuilder(linker);
    const segments = sb.@"0";

    const segment_count = sb.@"1" + 1; // +1 for the PHDR
    defer linker.allocator.free(segments);

    linker.mutElf.pheaders = std.ArrayList(elf.ProgramHeader).empty;
    const pheaders = &linker.mutElf.pheaders.?;
    var load_count: usize = 0;
    var memsz: u64 = 0;

    try pheaders.append(linker.allocator, generatePHDR(segment_count));

    for (segments) |*segment| {
        switch (segment.*) {
            .SEGMENT_START => |start| {
                memsz = 0;
                const is_first_load = load_count == 0 and start.@"0" == .PT_LOAD;
                if (is_first_load) {
                    memsz += 0x40 + 56 * segment_count;
                }
                try pheaders.append(linker.allocator, elf.ProgramHeader{
                    .type = start.@"0",
                    .flags = start.@"1",
                    .offset = if (is_first_load) 0 else start.@"3" + segment_count * @sizeOf(elf.ProgramHeader),
                    .vaddr = if (is_first_load) elf.START_ADDR else 0,
                    .paddr = if (is_first_load) elf.START_ADDR else 0,
                    .filesz = memsz,
                    .memsz = memsz,
                    .align_ = start.@"2",
                });
                if (start.@"0" == .PT_LOAD) load_count += 1;
            },
            .SEGMENT_END => {
                const pheader = &pheaders.items[pheaders.items.len - 1];
                pheader.setSize(memsz);
            },
            .SECTION => |section| {
                memsz += section.data.len;
                const pheader = &pheaders.items[pheaders.items.len - 1];
                if (pheader.vaddr == 0) {
                    pheader.setAddr(section.addr);
                }
            },
        }
    }
}

fn generatePHDR(segment_count: u32) elf.ProgramHeader {
    const sizeof = (segment_count) * @sizeOf(elf.ProgramHeader);
    const phdr = elf.ProgramHeader{
        .type = elf.ProgramHeader.Type.PT_PHDR,
        .flags = 0b100,
        .offset = 0x40,
        .vaddr = elf.START_ADDR | 0x40,
        .paddr = elf.START_ADDR | 0x40,
        .filesz = sizeof,
        .memsz = sizeof,
        .align_ = 0x8,
    };

    return phdr;
}
