const std = @import("std");
const elf = @import("elf");
const ElfLinker = @import("linker.zig").ElfLinker;

const SegmentArray = std.ArrayList(*elf.Section);

const Segment = union(enum) {
    SEGMENT_START: struct { elf.PHType, u32, u64 },
    SEGMENT_END,
    SECTION: *elf.Section,
};

fn SegmentBuilder(linker: *ElfLinker) !struct { []Segment, u32 } {
    const sections = linker.mutElf.sections.items;

    var segments = std.AutoHashMap(struct { elf.PHType, u32 }, SegmentArray).init(linker.allocator);
    defer segments.deinit();

    defer {
        var value_iter = segments.valueIterator();
        while (value_iter.next()) |entry| {
            entry.deinit();
        }
    }

    // TODO: refactor redundant code
    for (sections) |*section| {
        if (std.mem.eql(u8, section.name, ".interp")) {
            const interp = try segments.getOrPutValue(.{ .PT_INTERP, 0b100 }, SegmentArray.init(linker.allocator));
            try interp.value_ptr.append(section);
        } else if (section.flags & 0b110 == 0b110) {
            const load = try segments.getOrPutValue(.{ .PT_LOAD, 0b101 }, SegmentArray.init(linker.allocator));
            try load.value_ptr.append(section);
        } else if (section.flags & 0b011 == 0b011) {
            const load = try segments.getOrPutValue(.{ .PT_LOAD, 0b110 }, SegmentArray.init(linker.allocator));
            try load.value_ptr.append(section);
        } else if (section.type == .SHT_NOTE) {
            const load = try segments.getOrPutValue(.{ .PT_LOAD, 0b100 }, SegmentArray.init(linker.allocator));
            try load.value_ptr.append(section);
            const note = try segments.getOrPutValue(.{ .PT_NOTE, 0b100 }, SegmentArray.init(linker.allocator));
            try note.value_ptr.append(section);
        } else if (section.flags & 0b010 == 0b010) {
            const load = try segments.getOrPutValue(.{ .PT_LOAD, 0b100 }, SegmentArray.init(linker.allocator));
            try load.value_ptr.append(section);
        } else {
            return error.UnmappedSection;
        }
    }

    var segment_format = std.ArrayList(Segment).init(linker.allocator);
    defer segment_format.deinit();

    // TODO: verify the sections are continuous
    var segment_count: u32 = 0;

    if (segments.get(.{ .PT_INTERP, 0b100 })) |*interp| {
        try segment_format.append(.{ .SEGMENT_START = .{ .PT_INTERP, 0b100, 0x1 } });
        segment_count += 1;
        for (interp.items) |section| try segment_format.append(.{ .SECTION = section });

        try segment_format.append(.SEGMENT_END);
    }

    if (segments.get(.{ .PT_LOAD, 0b100 })) |*load| {
        try segment_format.append(.{ .SEGMENT_START = .{ .PT_LOAD, 0b100, 0x1000 } });
        segment_count += 1;
        for (load.items) |section| try segment_format.append(.{ .SECTION = section });

        try segment_format.append(.SEGMENT_END);
    }

    if (segments.get(.{ .PT_NOTE, 0b100 })) |*note| {
        try segment_format.append(.{ .SEGMENT_START = .{ .PT_NOTE, 0b100, 0x8 } });
        segment_count += 1;
        for (note.items) |section| try segment_format.append(.{ .SECTION = section });

        try segment_format.append(.SEGMENT_END);
    }
    if (segments.get(.{ .PT_LOAD, 0b101 })) |*load| {
        segment_count += 1;
        try segment_format.append(.{ .SEGMENT_START = .{ .PT_LOAD, 0b101, 0x1000 } });
        for (load.items) |section| try segment_format.append(.{ .SECTION = section });

        try segment_format.append(.SEGMENT_END);
    }
    if (segments.get(.{ .PT_LOAD, 0b110 })) |*load| {
        segment_count += 1;
        try segment_format.append(.{ .SEGMENT_START = .{ .PT_LOAD, 0b110, 0x1000 } });
        for (load.items) |section| try segment_format.append(.{ .SECTION = section });

        try segment_format.append(.SEGMENT_END);
    }

    return .{ try segment_format.toOwnedSlice(), segment_count };
}

pub fn generatePheaders(linker: *ElfLinker) !void {
    const sb = try SegmentBuilder(linker);
    const segments = sb.@"0";
    const segment_count = sb.@"1" + 1; // +1 for the PHDR
    defer linker.allocator.free(segments);

    const sections = linker.mutElf.sections.items;

    var vaddr: u64 = (elf.START_ADDR | 64) + segment_count * @sizeOf(elf.ProgramHeader);

    for (sections) |*section| {
        section.addr = vaddr;
        vaddr += section.data.len;
    }

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
                    .offset = 0,
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
                if (pheader.type == .PT_LOAD) {
                    section.addr += (load_count - 1) * 0x1000;
                }
                if (pheader.vaddr == 0) {
                    pheader.setAddr(section.addr);
                    pheader.offset = section.addr - elf.START_ADDR - (load_count - 1) * 0x1000; // FIXME: Temporary hack
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
