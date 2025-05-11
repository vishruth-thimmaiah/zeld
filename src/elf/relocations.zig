pub const Relocation = struct {
    offset: u64,
    info: u64,
    addend: i64,

    pub fn get_symbol(self: Relocation) usize {
        return self.info >> 32;
    }

    pub fn set_symbol(self: *Relocation, symbol: usize) void {
        self.info = (symbol << 32) + self.get_type();
    }

    pub fn get_type(self: Relocation) usize {
        return self.info & 0xffffffff;
    }

    pub fn set_type(self: *Relocation, typeval: usize) void {
        self.info = self.get_symbol() << 32 + typeval;
    }
};
