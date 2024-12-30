const std = @import("std");

const rl = @import("raylib");

const PieceShapes = enum {
    i,
    l,
    j,
    o,
    s,
    z,
    t,
    pub fn toColor(self: PieceShapes) rl.Color {
        switch (self) {
            .i => {
                return rl.Color.fromInt(0x01E6FEFF);
            },
            .l => {
                return rl.Color.fromInt(0x1801FFFF);
            },
            .j => {
                return rl.Color.fromInt(0xFF7308FF);
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
const Direction = enum { North, East, South, West };
const pieceCount = 7;
const screenWidth = 1600;
const screenHeight = 900;
const playfieldHeight = 24;
const visiblePlayfieldHeight = 22;
const playfieldWidth = 10;
const squareSideLength = screenHeight / (visiblePlayfieldHeight + 3);
const BitSetPlayfield = std.bit_set.IntegerBitSet(playfieldWidth * playfieldHeight);
var piecePlayfield: [pieceCount]BitSetPlayfield = undefined;
var pieceBag = std.bit_set.IntegerBitSet(pieceCount).initFull();

pub fn main() !void {
    for (0..pieceCount) |i| {
        piecePlayfield[i] = BitSetPlayfield.initEmpty();
    }

    rl.initWindow(screenWidth, screenHeight, "zigtris");
    defer rl.closeWindow();

    rl.setTargetFPS(120);

    // var prng = std.Random.DefaultPrng.init(0);
    const Queue = std.DoublyLinkedList(PieceShapes);
    var pieceQueue = Queue{};

    // while (pieceBag.mask != 0) {
    //     const bagIdx = prng.random().intRangeLessThan(usize, 0, pieceCount);
    //     if (pieceBag.isSet(bagIdx)) {
    //         var newNode = Queue.Node{ .data = @enumFromInt(bagIdx) };
    //         pieceQueue.prepend(&newNode);
    //         pieceBag.unset(bagIdx);
    //     }
    // }

    var newNode = Queue.Node{ .data = PieceShapes.o };
    pieceQueue.prepend(&newNode);

    pieceBag.setUnion(std.bit_set.IntegerBitSet(pieceCount).initFull());
    const currentShape = pieceQueue.pop().?.data;
    var currentShapePlayfield = BitSetPlayfield.initEmpty();

    while (!rl.windowShouldClose()) {
        // Update
        {
            if (currentShapePlayfield.mask == 0) {
                spawnPiece(currentShape, &currentShapePlayfield);
            }

            if (rl.isKeyPressed(rl.KeyboardKey.key_down)) {
                moveShape(currentShape, &currentShapePlayfield, Direction.South);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_up)) {
                moveShape(currentShape, &currentShapePlayfield, Direction.North);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_left)) {
                moveShape(currentShape, &currentShapePlayfield, Direction.West);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_right)) {
                moveShape(currentShape, &currentShapePlayfield, Direction.East);
            }
        }
        // Draw
        {
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(rl.Color.ray_white);
            drawBackgroundPlayfield();
            for (0..pieceCount) |i| {
                drawPlayfield(@enumFromInt(i), &piecePlayfield[i]);
            }
            drawPlayfield(currentShape, &currentShapePlayfield);
        }
    }
}

fn drawBackgroundPlayfield() void {
    for (0..visiblePlayfieldHeight) |y| {
        for (0..playfieldWidth) |x| {
            var rectColor: rl.Color = undefined;
            if ((x + y) % 2 == 0) {
                rectColor = rl.Color.fromInt(0x000000FF);
            } else {
                rectColor = rl.Color.fromInt(0x0F0F0FFF);
            }

            const xidx: i32 = @intCast(@as(u64, x));
            const yidx: i32 = @intCast(@as(u64, y));
            const xpos: i32 = xidx * squareSideLength + (screenWidth / 2 - (squareSideLength * playfieldWidth / 2));
            const ypos: i32 = (yidx + 1) * squareSideLength;
            rl.drawRectangle(xpos, ypos, squareSideLength, squareSideLength, rectColor);
        }
    }
}

fn drawPlayfield(shape: PieceShapes, playfield: *const BitSetPlayfield) void {
    for (0..playfieldHeight) |y| {
        for (0..playfieldWidth) |x| {
            if (playfield.isSet(y * playfieldWidth + x)) {
                const xidx: i32 = @intCast(@as(u64, x));
                const yidx: i32 = @intCast(@as(u64, y));
                const xpos: i32 = xidx * squareSideLength + (screenWidth / 2 - (squareSideLength * playfieldWidth / 2));
                const ypos: i32 = (yidx - (playfieldHeight - visiblePlayfieldHeight) + 1) * squareSideLength;
                rl.drawRectangle(xpos, ypos, squareSideLength, squareSideLength, shape.toColor());
            }
        }
    }
}
fn moveShape(currentShape: PieceShapes, currentShapePlayfield: *BitSetPlayfield, direction: Direction) void {
    switch (currentShape) {
        PieceShapes.i => {},
        PieceShapes.l => {},
        PieceShapes.j => {},
        PieceShapes.o => {
            if (currentShapePlayfield.findFirstSet()) |topLeftIdx| {
                const xpos: i32 = @intCast(@rem(topLeftIdx, playfieldWidth));
                const ypos: i32 = @intCast(@divFloor(topLeftIdx, playfieldWidth));
                var offsetX: i32 = 0;
                var offsetY: i32 = 0;
                switch (direction) {
                    Direction.North => {
                        offsetY = -1;
                    },
                    Direction.East => {
                        offsetX = 1;
                    },
                    Direction.South => {
                        offsetY = 1;
                    },
                    Direction.West => {
                        offsetX = -1;
                    },
                }

                const futureXpos = [4]i32{ xpos + offsetX, xpos + 1 + offsetX, xpos + offsetX, xpos + 1 + offsetX };
                const futureYpos = [4]i32{ ypos + offsetY, ypos + offsetY, ypos + 1 + offsetY, ypos + 1 + offsetY };
                var moveIsValid = true;

                for (futureXpos, futureYpos) |futXPos, futYPos| {
                    if (futXPos < 0 or futXPos >= playfieldWidth or futYPos < 0 or futYPos >= playfieldHeight) {
                        moveIsValid = false;
                        break;
                    }
                }
                if (moveIsValid) {
                    currentShapePlayfield.setIntersection(BitSetPlayfield.initEmpty());
                    for (futureXpos, futureYpos) |futXPos, futYPos| {
                        const futXCast: usize = @intCast(futXPos);
                        const futYCast: usize = @intCast(futYPos);
                        const bitIdx: usize = futYCast * playfieldWidth + futXCast;
                        currentShapePlayfield.set(bitIdx);
                    }
                }
            }
        },
        PieceShapes.s => {},
        PieceShapes.z => {},
        PieceShapes.t => {},
    }
}
fn spawnPiece(currentShape: PieceShapes, currentShapePlayfield: *BitSetPlayfield) void {
    switch (currentShape) {
        PieceShapes.i => {},
        PieceShapes.l => {},
        PieceShapes.j => {},
        PieceShapes.o => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 1, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 1, 2, 1, 2 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                const futXCast: usize = @intCast(futXPos);
                const futYCast: usize = @intCast(futYPos);
                const bitIdx: usize = futYCast * playfieldWidth + futXCast;
                currentShapePlayfield.set(bitIdx);
            }
        },
        PieceShapes.s => {},
        PieceShapes.z => {},
        PieceShapes.t => {},
    }
}
