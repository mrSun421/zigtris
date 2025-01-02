const rl = @import("raylib");
pub const PieceShape = enum {
    i,
    l,
    j,
    o,
    s,
    z,
    t,
    pub fn toColor(self: PieceShape) rl.Color {
        switch (self) {
            .i => {
                return rl.Color.fromInt(0x01E6FEFF);
            },
            .l => {
                return rl.Color.fromInt(0xFF7308FF);
            },
            .j => {
                return rl.Color.fromInt(0x1801FFFF);
            },
            .o => {
                return rl.Color.fromInt(0xFFDE00FF);
            },
            .s => {
                return rl.Color.fromInt(0x66FD00FF);
            },
            .z => {
                return rl.Color.fromInt(0xFE103CFF);
            },
            .t => {
                return rl.Color.fromInt(0xB802FDFF);
            },
        }
    }
};
