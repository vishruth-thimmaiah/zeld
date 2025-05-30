pub const Relocation = struct {
    offset: u64,
    info: u64,
    addend: i64,

    pub fn get_symbol(self: Relocation) usize {
        return self.info >> 32;
    }

    pub fn set_symbol(self: *Relocation, symbol: usize) void {
        self.info = (symbol << 32) + @intFromEnum(self.get_type());
    }

    pub fn get_type(self: Relocation) RTypes {
        return @enumFromInt(self.info & 0xffffffff);
    }

    pub fn set_type(self: *Relocation, typeval: RTypes) void {
        self.info = self.get_symbol() << 32 + @intFromEnum(typeval);
    }
};

pub const RTypes = enum(u32) {
    R_X86_64_NONE = 0,
    R_X86_64_64 = 1,
    R_X86_64_PC32 = 2,
    R_X86_64_GOT32 = 3,
    R_X86_64_PLT32 = 4,
    R_X86_64_COPY = 5,
    R_X86_64_GLOB_DAT = 6,
    R_X86_64_JUMP_SLOT = 7,
    R_X86_64_RELATIVE = 8,
    R_X86_64_GOTPCREL = 9,
    R_X86_64_32 = 10,
    R_X86_64_32S = 11,
    R_X86_64_16 = 12,
    R_X86_64_PC16 = 13,
    R_X86_64_8 = 14,
    R_X86_64_PC8 = 15,
    R_X86_64_DTPMOD64 = 16,
    R_X86_64_DTPOFF64 = 17,
    R_X86_64_TPOFF64 = 18,
    R_X86_64_TLSGD = 19,
    R_X86_64_TLSLD = 20,
    R_X86_64_DTPOFF32 = 21,
    R_X86_64_GOTTPOFF = 22,
    R_X86_64_TPOFF32 = 23,
    R_X86_64_PC64 = 24,
    R_X86_64_GOTOFF64 = 25,
    R_X86_64_GOTPC32 = 26,
    R_X86_64_GOT64 = 27,
    R_X86_64_GOTPCREL64 = 28,
    R_X86_64_GOTPC64 = 29,
    R_X86_64_GOTPLT64 = 30,
    R_X86_64_PLTOFF64 = 31,
    R_X86_64_SIZE32 = 32,
    R_X86_64_SIZE64 = 33,
    R_X86_64_GOTPC32_TLSDESC = 34,
    R_X86_64_TLSDESC_CALL = 35,
    R_X86_64_TLSDESC = 36,
    R_X86_64_IRELATIVE = 37,
    R_X86_64_RELATIVE64 = 38,
    R_X86_64_GOTPCRELX = 41,
    R_X86_64_REX_GOTPCRELX = 42,
    R_X86_64_NUM = 43,
};
