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
const RotationStates = enum { Zero, Right, Left, Two };

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

const CurrentShapeData = struct { shape: PieceShapes, playfield: *BitSetPlayfield, rotation: RotationStates };

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
    var currentShapePlayfield = BitSetPlayfield.initEmpty();
    var currentShapeData = CurrentShapeData{ .shape = pieceQueue.pop().?.data, .playfield = &currentShapePlayfield, .rotation = RotationStates.Zero };

    while (!rl.windowShouldClose()) {
        // Update
        {
            if (currentShapePlayfield.mask == 0) {
                spawnPiece(&currentShapeData);
            }

            if (rl.isKeyPressed(rl.KeyboardKey.key_down)) {
                moveShape(&currentShapeData, Direction.South);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_up)) {
                moveShape(&currentShapeData, Direction.North);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_left)) {
                moveShape(&currentShapeData, Direction.West);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_right)) {
                moveShape(&currentShapeData, Direction.East);
            }
            if (rl.isKeyPressed(rl.KeyboardKey.key_z)) {
                // rotateShapeRight(currentShape, &currentShapePlayfield, currentRotation);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_x)) {
                // rotateShapeLeft(currentShape, &currentShapePlayfield, currentRotation);
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
            drawPlayfield(currentShapeData.shape, currentShapeData.playfield);
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
fn moveShape(currentShapeData: *CurrentShapeData, direction: Direction) void {
    switch (currentShapeData.shape) {
        PieceShapes.i => {},
        PieceShapes.l => {},
        PieceShapes.j => {},
        PieceShapes.o => {
            var tempidx: usize = 0;
            var posCount: usize = 0;

            var filledXPos: [4]i32 = undefined;
            var filledYPos: [4]i32 = undefined;

            while (posCount < 4) : (tempidx += 1) {
                if (currentShapeData.playfield.isSet(tempidx)) {
                    filledXPos[posCount] = @intCast(@rem(tempidx, playfieldWidth));
                    filledYPos[posCount] = @intCast(@divFloor(tempidx, playfieldWidth));
                    posCount += 1;
                }
            }
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
            var futureXpos: [4]i32 = undefined;
            var futureYpos: [4]i32 = undefined;
            for (filledXPos, filledYPos, 0..) |xPos, yPos, i| {
                futureXpos[i] = xPos + offsetX;
                futureYpos[i] = yPos + offsetY;
            }

            var moveIsValid = true;

            for (futureXpos, futureYpos) |futXPos, futYPos| {
                if (futXPos < 0 or futXPos >= playfieldWidth or futYPos < 0 or futYPos >= playfieldHeight) {
                    moveIsValid = false;
                    break;
                }
            }
            if (moveIsValid) {
                currentShapeData.playfield.setIntersection(BitSetPlayfield.initEmpty());
                for (futureXpos, futureYpos) |futXPos, futYPos| {
                    const futXCast: usize = @intCast(futXPos);
                    const futYCast: usize = @intCast(futYPos);
                    const bitIdx: usize = futYCast * playfieldWidth + futXCast;
                    currentShapeData.playfield.set(bitIdx);
                }
            }
        },
        PieceShapes.s => {},
        PieceShapes.z => {},
        PieceShapes.t => {},
    }
}
fn spawnPiece(currenShapeData: *CurrentShapeData) void {
    switch (currenShapeData.shape) {
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
                currenShapeData.playfield.set(bitIdx);
            }
        },
        PieceShapes.s => {},
        PieceShapes.z => {},
        PieceShapes.t => {},
    }
}
