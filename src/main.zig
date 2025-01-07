const std = @import("std");

const rl = @import("raylib");

const PieceQueue = @import("pieceQueue.zig").PieceQueue;
const PieceShape = @import("pieceShape.zig").PieceShape;
const Timer = @import("timer.zig").Timer;
const RotationState = @import("rotationState.zig").RotationState;

const Direction = enum { North, East, South, West };
const RotationAction = enum { Right, Left };

const pieceCount = 7;
const screenWidth = 1600;
const screenHeight = 900;
const playfieldHeight = 24;
const visiblePlayfieldHeight = 22;
const playfieldWidth = 10;
const squareSideLength = screenHeight / (visiblePlayfieldHeight + 3);
const BitSetPlayfield = std.bit_set.IntegerBitSet(playfieldWidth * playfieldHeight);
fn printBitSetPlayfield(playfield: BitSetPlayfield) void {
    inline for (0..BitSetPlayfield.bit_length / playfieldWidth) |i| {
        const val = (playfield.mask >> (playfieldWidth * i) & (0b1111111111));
        std.debug.print("{b:0<10}\n", .{val});
    }
}
var piecePlayfield: [pieceCount]BitSetPlayfield = undefined;

const CurrentShapeData = struct { shape: PieceShape, playfield: *BitSetPlayfield, rotation: RotationState, rotationPointX: i32, rotationPointY: i32 };

fn initData() void {
    for (0..pieceCount) |i| {
        piecePlayfield[i] = BitSetPlayfield.initEmpty();
    }
}

pub fn main() !void {
    initData();

    rl.initWindow(screenWidth, screenHeight, "zigtris");
    defer rl.closeWindow();

    rl.setTargetFPS(120);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var pieceQueue = PieceQueue.init();

    var currentShapePlayfield = BitSetPlayfield.initEmpty();
    var currentShapeData = CurrentShapeData{ .shape = undefined, .playfield = &currentShapePlayfield, .rotation = RotationState.Zero, .rotationPointX = 0, .rotationPointY = 0 };

    var lockTimer: Timer = undefined;
    lockTimer.disable();
    var gravityTimer: Timer = undefined;
    gravityTimer.disable();
    var spawnTimer: Timer = undefined;
    spawnTimer.start(0.01);

    var heldPiece: ?PieceShape = null;
    var holdPressed: bool = false;

    while (!rl.windowShouldClose()) {
        // Update
        {
            if (pieceQueue.len < pieceCount) {
                pieceQueue.addPiece();
            }

            if (lockTimer.isDone()) {
                lockCurrentShape(&currentShapeData);
                holdPressed = false;
                gravityTimer.disable();
                lockTimer.disable();
                spawnTimer.start(0.1);
            }
            if (gravityTimer.isDone()) {
                const moveIsValid = moveShape(&currentShapeData, Direction.South);
                if (!moveIsValid) {
                    if (!lockTimer.isEnabled()) {
                        lockTimer.start(0.5);
                    }
                } else {
                    gravityTimer.start(0.5);
                }
            }
            if (spawnTimer.isDone()) {
                spawnTimer.disable();
                spawnPiece(pieceQueue.dequeue(), &currentShapeData);
                gravityTimer.start(0.5);
            }

            if (rl.isKeyPressed(rl.KeyboardKey.key_down)) {
                const moveIsValid = moveShape(&currentShapeData, Direction.South);
                if (!moveIsValid) {
                    if (!lockTimer.isEnabled()) {
                        lockTimer.start(0.5);
                    }
                } else {
                    gravityTimer.start(0.5);
                }
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_left)) {
                _ = moveShape(&currentShapeData, Direction.West);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_right)) {
                _ = moveShape(&currentShapeData, Direction.East);
            }
            if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
                while (moveShape(&currentShapeData, Direction.South)) {}
                holdPressed = false;
                lockTimer.start(0.01);
            }
            if (rl.isKeyPressed(rl.KeyboardKey.key_z)) {
                rotateShape(&currentShapeData, RotationAction.Left);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_x)) {
                rotateShape(&currentShapeData, RotationAction.Right);
            }
            if (rl.isKeyPressed(rl.KeyboardKey.key_left_shift) and !holdPressed) {
                holdPressed = true;
                const currentPiece = currentShapeData.shape;
                currentShapeData.playfield.setIntersection(BitSetPlayfield.initEmpty());
                if (heldPiece) |held| {
                    spawnPiece(held, &currentShapeData);
                    gravityTimer.start(0.5);
                } else {
                    spawnPiece(pieceQueue.dequeue(), &currentShapeData);
                    gravityTimer.start(0.5);
                }
                heldPiece = currentPiece;
            }

            var rowIdx: usize = 0;
            while (rowIdx < playfieldHeight) {
                var allFilledPlayfield = BitSetPlayfield.initEmpty();
                for (piecePlayfield) |playfield| {
                    allFilledPlayfield.setUnion(playfield);
                }
                const i = rowIdx;
                var lineChecker: BitSetPlayfield = BitSetPlayfield.initEmpty();
                lineChecker.setRangeValue(.{ .start = i * playfieldWidth, .end = i * playfieldWidth + playfieldWidth }, true);
                const currentLine = lineChecker.intersectWith(allFilledPlayfield.complement());
                if (currentLine.mask != 0) {
                    rowIdx += 1;
                } else {
                    for (0..piecePlayfield.len) |j| {
                        piecePlayfield[j].setIntersection(lineChecker.complement());
                        var tempPlayfield = BitSetPlayfield.initEmpty();
                        tempPlayfield.setUnion(piecePlayfield[j]);
                        var topMask = BitSetPlayfield.initEmpty();
                        topMask.setRangeValue(.{ .start = 0, .end = i * playfieldWidth }, true);
                        piecePlayfield[j].setIntersection(topMask.complement());
                        tempPlayfield.setIntersection(topMask);
                        tempPlayfield.mask <<= playfieldWidth;
                        piecePlayfield[j].setUnion(tempPlayfield);
                    }
                }
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

            const nextPieces = try pieceQueue.peekAll(arena.allocator());
            defer arena.allocator().destroy(&nextPieces);
            drawNextPieces(nextPieces);
            drawPieceWithBackground(heldPiece, rl.Rectangle.init(screenWidth / 4, squareSideLength * 4, squareSideLength * 4, squareSideLength * 4));
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

fn drawPlayfield(shape: PieceShape, playfield: *const BitSetPlayfield) void {
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
fn moveShape(currentShapeData: *CurrentShapeData, direction: Direction) bool {
    var allFilledPlayfield = BitSetPlayfield.initEmpty();
    for (piecePlayfield) |playfield| {
        allFilledPlayfield.setUnion(playfield);
    }
    if (getFuturePlayfield(currentShapeData, direction)) |futurePlayfield| {
        const checkPlayfield = allFilledPlayfield.intersectWith(futurePlayfield);
        if (checkPlayfield.mask != 0) {
            return false;
        } else {
            currentShapeData.playfield.mask = futurePlayfield.mask;
            var offsetX: i32 = 0;
            var offsetY: i32 = 0;
            switch (direction) {
                .North => {
                    offsetY = -1;
                },
                .East => {
                    offsetX = 1;
                },
                .South => {
                    offsetY = 1;
                },
                .West => {
                    offsetX = -1;
                },
            }
            currentShapeData.rotationPointX += offsetX;
            currentShapeData.rotationPointY += offsetY;
            return true;
        }
    } else {
        return false;
    }
}

fn getFuturePlayfield(currentShapeData: *CurrentShapeData, direction: Direction) ?BitSetPlayfield {
    var offsetX: i32 = 0;
    var offsetY: i32 = 0;
    switch (direction) {
        .North => {
            offsetY = -1;
        },
        .East => {
            offsetX = 1;
        },
        .South => {
            offsetY = 1;
        },
        .West => {
            offsetX = -1;
        },
    }
    var tempidx: usize = 0;
    var posCount: usize = 0;

    var filledXPos: [4]i32 = undefined;
    var filledYPos: [4]i32 = undefined;

    while (posCount < 4) : (tempidx += 1) {
        if (tempidx >= BitSetPlayfield.bit_length) {
            return null;
        }
        if (currentShapeData.playfield.isSet(tempidx)) {
            filledXPos[posCount] = @intCast(@rem(tempidx, playfieldWidth));
            filledYPos[posCount] = @intCast(@divFloor(tempidx, playfieldWidth));
            posCount += 1;
        }
    }

    var futureXpos: [4]i32 = undefined;
    var futureYpos: [4]i32 = undefined;
    for (filledXPos, filledYPos, 0..) |xPos, yPos, i| {
        futureXpos[i] = xPos + offsetX;
        futureYpos[i] = yPos + offsetY;
    }

    if (!coordinatesAreValid(futureXpos, futureYpos)) {
        return null;
    }

    var futurePlayfield = BitSetPlayfield.initEmpty();
    for (futureXpos, futureYpos) |futXPos, futYPos| {
        const futXCast: usize = @intCast(futXPos);
        const futYCast: usize = @intCast(futYPos);
        const bitIdx: usize = futYCast * playfieldWidth + futXCast;
        futurePlayfield.set(bitIdx);
    }
    return futurePlayfield;
}

fn spawnPiece(shape: PieceShape, currenShapeData: *CurrentShapeData) void {
    currenShapeData.rotation = RotationState.Zero;
    currenShapeData.shape = shape;
    switch (shape) {
        .i => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 + 1 };
            const futureYpos = [4]i32{ 1, 1, 1, 1 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
            currenShapeData.rotationPointX = futureXpos[1];
            currenShapeData.rotationPointY = futureYpos[1];
        },
        .l => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 2, 2, 2, 1 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
            currenShapeData.rotationPointX = futureXpos[1];
            currenShapeData.rotationPointY = futureYpos[1];
        },
        .j => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 1, 2, 2, 2 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
            currenShapeData.rotationPointX = futureXpos[2];
            currenShapeData.rotationPointY = futureYpos[2];
        },
        .o => {
            currenShapeData.shape = PieceShape.o;
            const futureXpos = [4]i32{ playfieldWidth / 2 - 1, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 1, 2, 1, 2 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
            currenShapeData.rotationPointX = futureXpos[2];
            currenShapeData.rotationPointY = futureYpos[2];
        },
        .s => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2, playfieldWidth / 2 + 1 };
            const futureYpos = [4]i32{ 2, 2, 1, 1 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
            currenShapeData.rotationPointX = futureXpos[1];
            currenShapeData.rotationPointY = futureYpos[1];
        },
        .z => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2 - 1, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 1, 1, 2, 2 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
            currenShapeData.rotationPointX = futureXpos[1];
            currenShapeData.rotationPointY = futureYpos[1];
        },
        .t => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 - 1 };
            const futureYpos = [4]i32{ 2, 2, 2, 1 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
            currenShapeData.rotationPointX = futureXpos[1];
            currenShapeData.rotationPointY = futureYpos[1];
        },
    }
}

fn setPlayfieldFromPosition(playfield: *BitSetPlayfield, xpos: i32, ypos: i32) void {
    const xCast: usize = @intCast(xpos);
    const yCast: usize = @intCast(ypos);
    const bitIdx: usize = yCast * playfieldWidth + xCast;
    playfield.set(bitIdx);
}
fn lockCurrentShape(currentShapeData: *CurrentShapeData) void {
    piecePlayfield[@intFromEnum(currentShapeData.shape)].setUnion(currentShapeData.playfield.*);
    currentShapeData.playfield.setIntersection(BitSetPlayfield.initEmpty());
}

fn drawNextPieces(nextPieces: []PieceShape) void {
    for (0..5) |i| {
        const piece = nextPieces[i];
        const idx: f32 = @floatFromInt(i);
        const background = rl.Rectangle.init(screenWidth * 3 / 4, squareSideLength * (2 + 3 * idx), squareSideLength * 5, squareSideLength * 3);
        drawPieceWithBackground(piece, background);
    }
}

fn drawPieceWithBackground(shape: ?PieceShape, background: rl.Rectangle) void {
    rl.drawRectangleRec(background, rl.Color.black);
    if (shape) |shapeVal| {
        var pieceRects: [4]rl.Rectangle = [_]rl.Rectangle{rl.Rectangle.init(background.x, background.y, squareSideLength, squareSideLength)} ** 4;
        switch (shapeVal) {
            .i => {
                const pieceLength = squareSideLength * 4;
                const pieceHeight = squareSideLength;
                const offsetsX = [4]i32{ 0, 1, 2, 3 };
                const offsetsY = [4]i32{ 0, 0, 0, 0 };
                offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
            },
            .j => {
                const pieceLength = squareSideLength * 3;
                const pieceHeight = squareSideLength * 2;
                const offsetsX = [4]i32{ 0, 0, 1, 2 };
                const offsetsY = [4]i32{ 0, 1, 1, 1 };
                offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
            },
            .l => {
                const pieceLength = squareSideLength * 3;
                const pieceHeight = squareSideLength * 2;
                const offsetsX = [4]i32{ 0, 1, 2, 2 };
                const offsetsY = [4]i32{ 1, 1, 1, 0 };
                offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
            },
            .o => {
                const pieceLength = squareSideLength * 2;
                const pieceHeight = squareSideLength * 2;
                const offsetsX = [4]i32{ 0, 1, 0, 1 };
                const offsetsY = [4]i32{ 0, 0, 1, 1 };
                offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
            },
            .s => {
                const pieceLength = squareSideLength * 3;
                const pieceHeight = squareSideLength * 2;
                const offsetsX = [4]i32{ 0, 1, 1, 2 };
                const offsetsY = [4]i32{ 1, 1, 0, 0 };
                offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
            },
            .z => {
                const pieceLength = squareSideLength * 3;
                const pieceHeight = squareSideLength * 2;
                const offsetsX = [4]i32{ 0, 1, 1, 2 };
                const offsetsY = [4]i32{ 0, 0, 1, 1 };
                offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
            },
            .t => {
                const pieceLength = squareSideLength * 3;
                const pieceHeight = squareSideLength * 2;
                const offsetsX = [4]i32{ 0, 1, 1, 2 };
                const offsetsY = [4]i32{ 1, 1, 0, 1 };
                offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
            },
        }
        for (pieceRects) |pieceRect| {
            rl.drawRectangleRec(pieceRect, shapeVal.toColor());
        }
    }
}
fn offsetPieceRects(
    pieceRects: *[4]rl.Rectangle,
    background: rl.Rectangle,
    pieceLength: f32,
    pieceHeight: f32,
    offsetsX: [4]i32,
    offsetsY: [4]i32,
) void {
    for (0..4) |i| {
        // centering
        pieceRects[i].y += background.height / 2 - pieceHeight / 2;
        pieceRects[i].x += background.width / 2 - pieceLength / 2;
    }
    // make shape
    for (0..4) |i| {
        pieceRects[i].y += @floatFromInt(squareSideLength * offsetsY[i]);
        pieceRects[i].x += @floatFromInt(squareSideLength * offsetsX[i]);
    }
}

fn rotateShape(currentShapeData: *CurrentShapeData, rotationAction: RotationAction) void {
    for (0..5) |wallKickIdx| {
        var nextRotationState: RotationState = undefined;
        switch (rotationAction) {
            .Right => {
                nextRotationState = currentShapeData.rotation.rotateRight();
            },
            .Left => {
                nextRotationState = currentShapeData.rotation.rotateLeft();
            },
        }
        var tempidx: usize = 0;
        var posCount: usize = 0;

        var filledXPos: [4]i32 = undefined;
        var filledYPos: [4]i32 = undefined;

        while (posCount < 4) : (tempidx += 1) {
            if (tempidx >= (playfieldWidth * playfieldHeight)) {
                return;
            }
            if (currentShapeData.playfield.isSet(tempidx)) {
                filledXPos[posCount] = @intCast(@rem(tempidx, playfieldWidth));
                filledYPos[posCount] = @intCast(@divFloor(tempidx, playfieldWidth));
                posCount += 1;
            }
        }

        var futureXPos: [4]i32 = undefined;
        var futureYPos: [4]i32 = undefined;
        var temp: [4]i32 = undefined;
        @memcpy(&futureXPos, &filledXPos);
        @memcpy(&futureYPos, &filledYPos);
        for (0..4) |i| {
            futureXPos[i] -= currentShapeData.rotationPointX;
            futureYPos[i] -= currentShapeData.rotationPointY;
        }
        @memcpy(&temp, &futureYPos);
        @memcpy(&futureYPos, &futureXPos);
        @memcpy(&futureXPos, &temp);
        switch (rotationAction) {
            .Right => {
                for (futureXPos, 0..) |xPos, i| {
                    futureXPos[i] = -xPos;
                }
            },
            .Left => {
                for (futureYPos, 0..) |yPos, i| {
                    futureYPos[i] = -yPos;
                }
            },
        }
        const wallkickOffset = getWallkickOffset(currentShapeData.shape, currentShapeData.rotation, nextRotationState, wallKickIdx) orelse rl.Vector2.zero();
        const wallkickOffsetX: i32 = @intFromFloat(wallkickOffset.x);
        const wallkickOffsetY: i32 = @intFromFloat(wallkickOffset.y);
        for (0..4) |i| {
            futureXPos[i] += currentShapeData.rotationPointX + wallkickOffsetX;
            futureYPos[i] += currentShapeData.rotationPointY + wallkickOffsetY;
        }

        if (!coordinatesAreValid(futureXPos, futureYPos)) {
            continue;
        }

        var futurePlayfield = BitSetPlayfield.initEmpty();
        for (futureXPos, futureYPos) |futXPos, futYPos| {
            const futXCast: usize = @intCast(futXPos);
            const futYCast: usize = @intCast(futYPos);
            const bitIdx: usize = futYCast * playfieldWidth + futXCast;
            futurePlayfield.set(bitIdx);
        }
        var allFilledPlayfield = BitSetPlayfield.initEmpty();
        for (piecePlayfield) |playfield| {
            allFilledPlayfield.setUnion(playfield);
        }
        const checkPlayfield = allFilledPlayfield.intersectWith(futurePlayfield);
        if (checkPlayfield.mask != 0) {
            continue;
        } else {
            currentShapeData.playfield.mask = futurePlayfield.mask;
            currentShapeData.rotationPointX += wallkickOffsetX;
            currentShapeData.rotationPointY += wallkickOffsetY;
            break;
        }
    }
}

fn coordinatesAreValid(xPositions: [4]i32, yPositions: [4]i32) bool {
    for (xPositions, yPositions) |xPos, yPos| {
        if (xPos < 0 or xPos >= playfieldWidth or yPos < 0 or yPos >= playfieldHeight) {
            return false;
        }
    }
    return true;
}

fn getWallkickOffset(shape: PieceShape, currentRotationState: RotationState, nextRotationState: RotationState, idx: usize) ?rl.Vector2 {
    if (idx > 5) {
        return null;
    }
    switch (shape) {
        .i => {
            return getWallkickOffsetI(currentRotationState, nextRotationState, idx);
        },
        .l => {
            return getWallkickOffsetJLSTZ(currentRotationState, nextRotationState, idx);
        },
        .j => {
            return getWallkickOffsetJLSTZ(currentRotationState, nextRotationState, idx);
        },
        .o => {
            return rl.Vector2.zero();
        },
        .s => {
            return getWallkickOffsetJLSTZ(currentRotationState, nextRotationState, idx);
        },
        .z => {
            return getWallkickOffsetJLSTZ(currentRotationState, nextRotationState, idx);
        },
        .t => {
            return getWallkickOffsetJLSTZ(currentRotationState, nextRotationState, idx);
        },
    }
}

fn getWallkickOffsetI(currentRotationState: RotationState, nextRotationState: RotationState, idx: usize) rl.Vector2 {
    const currOffset: rl.Vector2 = getWallkickDataI(currentRotationState, idx);
    const nextOffset: rl.Vector2 = getWallkickDataI(nextRotationState, idx);
    return currOffset.subtract(nextOffset);
}

fn getWallkickDataI(rotation: RotationState, idx: usize) rl.Vector2 {
    switch (rotation) {
        .Zero => {
            const offsets = [5]rl.Vector2{
                rl.Vector2.zero(),
                rl.Vector2.init(-1, 0),
                rl.Vector2.init(2, 0),
                rl.Vector2.init(-1, 0),
                rl.Vector2.init(2, 0),
            };
            return offsets[idx];
        },
        .Right => {
            const offsets = [5]rl.Vector2{
                rl.Vector2.init(-1, 0),
                rl.Vector2.init(0, 0),
                rl.Vector2.init(0, 0),
                rl.Vector2.init(0, -1),
                rl.Vector2.init(0, -2),
            };
            return offsets[idx];
        },
        .Two => {
            const offsets = [5]rl.Vector2{
                rl.Vector2.init(-1, -1),
                rl.Vector2.init(1, -1),
                rl.Vector2.init(-2, -1),
                rl.Vector2.init(1, 0),
                rl.Vector2.init(-2, 0),
            };
            return offsets[idx];
        },
        .Left => {
            const offsets = [5]rl.Vector2{
                rl.Vector2.init(0, -1),
                rl.Vector2.init(0, -1),
                rl.Vector2.init(0, -1),
                rl.Vector2.init(0, 1),
                rl.Vector2.init(0, 2),
            };
            return offsets[idx];
        },
    }
}

fn getWallkickOffsetJLSTZ(currentRotationState: RotationState, nextRotationState: RotationState, idx: usize) rl.Vector2 {
    const currOffset: rl.Vector2 = getWallkickDataJLSTZ(currentRotationState, idx);
    const nextOffset: rl.Vector2 = getWallkickDataJLSTZ(nextRotationState, idx);
    return currOffset.subtract(nextOffset);
}
fn getWallkickDataJLSTZ(rotation: RotationState, idx: usize) rl.Vector2 {
    switch (rotation) {
        .Zero => {
            const offsets = [5]rl.Vector2{
                rl.Vector2.zero(),
                rl.Vector2.zero(),
                rl.Vector2.zero(),
                rl.Vector2.zero(),
                rl.Vector2.zero(),
            };
            return offsets[idx];
        },
        .Right => {
            const offsets = [5]rl.Vector2{
                rl.Vector2.zero(),
                rl.Vector2.init(1, 0),
                rl.Vector2.init(1, 1),
                rl.Vector2.init(0, -2),
                rl.Vector2.init(1, -2),
            };
            return offsets[idx];
        },
        .Two => {
            const offsets = [5]rl.Vector2{
                rl.Vector2.zero(),
                rl.Vector2.zero(),
                rl.Vector2.zero(),
                rl.Vector2.zero(),
                rl.Vector2.zero(),
            };
            return offsets[idx];
        },
        .Left => {
            const offsets = [5]rl.Vector2{
                rl.Vector2.zero(),
                rl.Vector2.init(-1, 0),
                rl.Vector2.init(-1, 1),
                rl.Vector2.init(0, -2),
                rl.Vector2.init(-1, -2),
            };
            return offsets[idx];
        },
    }
}
