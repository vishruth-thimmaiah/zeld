const ElfLinker = @import("../linker.zig").ElfLinker;
const parser = @import("../../parser/elf.zig");

const std = @import("std");

pub fn mergeSymbols(linker: *const ElfLinker, file: parser.Elf64) !void {}
