const std = @import("std");
const elf = @import("elf");

const header = @import("header.zig");
const sheader = @import("sheader.zig");
const section = @import("sections.zig");
const symbol = @import("symbols.zig");

pub const Dynlib = struct {
    path: []const u8,
    header: elf.Header,
    dynsym: []elf.Symbol,
    dynstr: elf.Section,

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, path: *[]const u8) !Dynlib {
        const file = std.fs.cwd().openFile(path.*, .{}) catch |err| {
            std.debug.print("Error {s}: Failed to open '{s}'\n", .{ @errorName(err), path });
            std.process.exit(1);
        };
        defer file.close();

        const stat = try file.stat();
        const filebuffer = try file.readToEndAlloc(allocator, stat.size);
        defer allocator.free(filebuffer);

        const fileHeader = try header.parse(allocator, filebuffer);
        const sheaders = try sheader.parse(allocator, filebuffer, fileHeader);
        defer allocator.free(sheaders);

        var dynlib = Dynlib{
            .path = path.*,
            .header = fileHeader,
            .dynsym = undefined,
            .dynstr = undefined,
            .allocator = allocator,
        };

        var symtab: elf.Section = undefined;
        defer symtab.deinit();
        var symtab_index: usize = undefined;

        for (sheaders, 0..) |*sh, i| {
            if (sh.type == .SHT_DYNSYM) {
                symtab = (try section.parseSection(allocator, filebuffer, sh, null)).?;
                symtab_index = i;
            } else if (sh.type == .SHT_STRTAB and sh.flags != 0) {
                dynlib.dynstr = (try section.parseSection(allocator, filebuffer, sh, null)).?;
            }
        }
        dynlib.dynsym = try symbol.parse(
            allocator,
            fileHeader,
            sheaders,
            null,
            &symtab,
            &dynlib.dynstr,
            symtab_index,
        );

        return dynlib;
    }

    pub fn checkSym(self: *const Dynlib, sym: *std.StringHashMap(*elf.Symbol)) void {
        for (self.dynsym) |*dynsym| {
            if (sym.get(dynsym.name)) |s| {
                s.set_type(dynsym.get_type());
            }
        }
    }

    pub fn deinit(self: *Dynlib) void {
        for (self.dynsym) |sym| sym.deinit();
        self.allocator.free(self.dynsym);
        self.dynstr.deinit();
    }
};
