const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

const SegmentArray = std.ArrayList(Segment);

const Segment = union(enum) {
    SEGMENT_START: struct { elf.PHType, u32, u64, u64 },
    SEGMENT_END,
    SECTION: *elf.Section,

    fn addSingleSegment(segments: *SegmentArray, section: *elf.Section, offset: u64, type_: elf.PHType, flags: u32, align_: u64) !void {
        try segments.append(.{ .SEGMENT_START = .{ type_, flags, align_, offset } });
        try segments.append(.{ .SECTION = section });
        try segments.append(.SEGMENT_END);
    }
};

fn SegmentBuilder(linker: *ElfLinker) !struct { []Segment, u32 } {
    const sections = linker.mutElf.sections.items;

    var segments = SegmentArray.init(linker.allocator);
    var other_segments = SegmentArray.init(linker.allocator);
    defer other_segments.deinit();

    var counter: u32 = 0;
    var addr: u64 = elf.START_ADDR;
    var offset: u64 = 0x40;

    for (sections) |*section| {
        if (std.mem.eql(u8, section.name, ".interp")) {
            try segments.append(.{ .SEGMENT_START = .{ .PT_INTERP, 0b100, 0x1, offset } });
            counter += 1;
            try segments.append(.{ .SECTION = section });
            try segments.append(.SEGMENT_END);
        }
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
                try segments.append(.{ .SEGMENT_START = .{ .PT_LOAD, flag, 0x1000, offset } });
                break :last segments.getLast();
            };
            if (last == .SECTION and last.SECTION.flags != section.flags) {
                counter += 1;
                addr += 0x1000;
                try segments.append(.SEGMENT_END);
                try segments.append(.{ .SEGMENT_START = .{ .PT_LOAD, flag, 0x1000, offset } });
            } else if (last == .SEGMENT_END) {
                counter += 1;
                addr += 0x1000;
                try segments.append(.{ .SEGMENT_START = .{ .PT_LOAD, flag, 0x1000, offset } });
            }
            try segments.append(.{ .SECTION = section });
        }

        if (section.type == .SHT_NOTE) {
            try Segment.addSingleSegment(&other_segments, section, offset, .PT_NOTE, 0b100, 0x8);
            counter += 1;
        }

        section.addr = addr;
        addr += section.data.len;
        offset += section.data.len;
    }
    try segments.append(.SEGMENT_END);

    try segments.appendSlice(other_segments.items);

    for (sections) |*section| {
        section.addr += 0x40 + (counter + 1) * @sizeOf(elf.ProgramHeader);
    }

    return .{ try segments.toOwnedSlice(), counter };
}

pub fn generatePheaders(linker: *ElfLinker) !void {
    const sb = try SegmentBuilder(linker);
    const segments = sb.@"0";

    const segment_count = sb.@"1" + 1; // +1 for the PHDR
    defer linker.allocator.free(segments);

    linker.mutElf.pheaders = std.ArrayList(elf.ProgramHeader).init(linker.allocator);
    const pheaders = &linker.mutElf.pheaders.?;
    var load_count: usize = 0;
    var memsz: u64 = 0;

    try pheaders.append(generatePHDR(segment_count));

    for (segments) |*segment| {
        switch (segment.*) {
            .SEGMENT_START => |start| {
                memsz = 0;
                if (load_count == 0) {
                    memsz += 0x40 + 56 * segment_count;
                }
                try pheaders.append(elf.ProgramHeader{
                    .type = start.@"0",
                    .flags = start.@"1",
                    .offset = if (load_count == 0) 0 else start.@"3" + segment_count * @sizeOf(elf.ProgramHeader),
                    .vaddr = if (load_count == 0) elf.START_ADDR else 0,
                    .paddr = if (load_count == 0) elf.START_ADDR else 0,
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
        .type = elf.PHType.PT_PHDR,
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
