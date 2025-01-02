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
const Direction = enum { North, East, South, West };
const RotationState = enum { Zero, Right, Left, Two };
const RotationAction = enum { Right, Left };
const Timer = struct {
    startTime: f64,
    lifeTime: f64,

    pub fn init() Timer {
        return Timer{ .startTime = rl.getTime(), .lifeTime = std.math.floatMax(f64) };
    }
    pub fn start(self: *Timer, lifeTime: f64) void {
        self.startTime = rl.getTime();
        self.lifeTime = lifeTime;
    }
    pub fn isDone(self: *Timer) bool {
        return rl.getTime() - self.startTime >= self.lifeTime;
    }
    pub fn getElapsed(self: *Timer) f64 {
        return rl.getTime() - self.startTime;
    }
    pub fn disable(self: *Timer) void {
        self.lifeTime = std.math.floatMax(f64);
    }
};

const pieceCount = 7;
const screenWidth = 1600;
const screenHeight = 900;
const playfieldHeight = 24;
const visiblePlayfieldHeight = 22;
const playfieldWidth = 10;
const squareSideLength = screenHeight / (visiblePlayfieldHeight + 3);
const BitSetPlayfield = std.bit_set.IntegerBitSet(playfieldWidth * playfieldHeight);
var piecePlayfield: [pieceCount]BitSetPlayfield = undefined;
var prng = std.Random.DefaultPrng.init(0);

const CurrentShapeData = struct { shape: PieceShapes, playfield: *BitSetPlayfield, rotation: RotationState };
const PieceQueue = struct {
    slice: [pieceCount]PieceShapes,
    start: usize,
    len: usize,
    bag: std.bit_set.IntegerBitSet(pieceCount),
    pub fn init() PieceQueue {
        var q = PieceQueue{
            .slice = [_]PieceShapes{@enumFromInt(0)} ** pieceCount,
            .start = 0,
            .len = 0,
            .bag = std.bit_set.IntegerBitSet(pieceCount).initFull(),
        };

        while (q.bag.mask != 0) {
            const bagIdx = prng.random().intRangeLessThan(usize, 0, pieceCount);
            if (q.bag.isSet(bagIdx)) {
                q.enqueue(@enumFromInt(bagIdx));
                q.bag.unset(bagIdx);
            }
        }

        return q;
    }

    pub fn enqueue(self: *PieceQueue, shape: PieceShapes) void {
        if (self.len >= pieceCount) {
            return;
        }
        const end = (self.start + self.len) % pieceCount;

        self.slice[end] = shape;
        self.len += 1;
    }
    pub fn dequeue(self: *PieceQueue) PieceShapes {
        // Should return an error if empty, but this queue will always be full
        const front = self.slice[self.start];
        self.start = (self.start + 1) % pieceCount;
        self.len -= 1;

        return front;
    }

    pub fn addPiece(self: *PieceQueue) void {
        if (self.bag.mask == 0) {
            self.bag.setUnion(std.bit_set.IntegerBitSet(pieceCount).initFull());
        }
        var pieceFound = false;
        while (!pieceFound) {
            const bagIdx = prng.random().intRangeLessThan(usize, 0, pieceCount);
            if (self.bag.isSet(bagIdx)) {
                pieceFound = true;
                self.enqueue(@enumFromInt(bagIdx));
                self.bag.unset(bagIdx);
            }
        }
    }

    pub fn getFront(self: *PieceQueue) PieceShapes {
        return self.slice[self.start];
    }
};

pub fn main() !void {
    for (0..pieceCount) |i| {
        piecePlayfield[i] = BitSetPlayfield.initEmpty();
    }

    rl.initWindow(screenWidth, screenHeight, "zigtris");
    defer rl.closeWindow();

    rl.setTargetFPS(120);

    var pieceQueue = PieceQueue.init();

    var currentShapePlayfield = BitSetPlayfield.initEmpty();
    var currentShapeData = CurrentShapeData{ .shape = undefined, .playfield = &currentShapePlayfield, .rotation = RotationState.Zero };

    var lockTimer: Timer = undefined;
    lockTimer.disable();

    while (!rl.windowShouldClose()) {
        // Update
        {
            if (pieceQueue.len < pieceCount) {
                pieceQueue.addPiece();
            }
            if (currentShapePlayfield.mask == 0) {
                spawnPiece(pieceQueue.dequeue(), &currentShapeData);
            }

            if (lockTimer.isDone()) {
                lockCurrentShape(&currentShapeData);
                lockTimer.disable();
            }

            if (rl.isKeyPressed(rl.KeyboardKey.key_down)) {
                const moveIsValid = moveShape(&currentShapeData, Direction.South);
                if (!moveIsValid) {
                    lockTimer.start(0.5);
                }
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_up)) {
                _ = moveShape(&currentShapeData, Direction.North);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_left)) {
                _ = moveShape(&currentShapeData, Direction.West);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_right)) {
                _ = moveShape(&currentShapeData, Direction.East);
            }
            if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
                while (moveShape(&currentShapeData, Direction.South)) {}
                lockCurrentShape(&currentShapeData);
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
            drawNextPiece(pieceQueue.getFront());
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
fn moveShape(currentShapeData: *CurrentShapeData, direction: Direction) bool {
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
            return moveIsValid;
        }
    }

    var futurePlayfield = BitSetPlayfield.initEmpty();
    for (futureXpos, futureYpos) |futXPos, futYPos| {
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
        moveIsValid = false;
        return moveIsValid;
    }
    if (moveIsValid) {
        currentShapeData.playfield.mask = futurePlayfield.mask;
    }
    return moveIsValid;
}
fn spawnPiece(shape: PieceShapes, currenShapeData: *CurrentShapeData) void {
    currenShapeData.rotation = RotationState.Zero;
    currenShapeData.shape = shape;
    switch (shape) {
        PieceShapes.i => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 + 1 };
            const futureYpos = [4]i32{ 1, 1, 1, 1 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
        },
        PieceShapes.l => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 2, 2, 2, 1 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
        },
        PieceShapes.j => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 1, 2, 2, 2 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
        },
        PieceShapes.o => {
            currenShapeData.shape = PieceShapes.o;
            const futureXpos = [4]i32{ playfieldWidth / 2 - 1, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 1, 2, 1, 2 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
        },
        PieceShapes.s => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2, playfieldWidth / 2 + 1 };
            const futureYpos = [4]i32{ 2, 2, 1, 1 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
        },
        PieceShapes.z => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2 - 1, playfieldWidth / 2 };
            const futureYpos = [4]i32{ 1, 1, 2, 2 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
        },
        PieceShapes.t => {
            const futureXpos = [4]i32{ playfieldWidth / 2 - 2, playfieldWidth / 2 - 1, playfieldWidth / 2, playfieldWidth / 2 - 1 };
            const futureYpos = [4]i32{ 2, 2, 2, 1 };
            for (futureXpos, futureYpos) |futXPos, futYPos| {
                setPlayfieldFromPosition(currenShapeData.playfield, futXPos, futYPos);
            }
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
fn drawNextPiece(shape: PieceShapes) void {
    const background = rl.Rectangle.init(screenWidth * 3 / 4, squareSideLength * 2, squareSideLength * 5, squareSideLength * 5);

    var pieceRects: [4]rl.Rectangle = [_]rl.Rectangle{rl.Rectangle.init(background.x, background.y, squareSideLength, squareSideLength)} ** 4;

    rl.drawRectangleRec(background, rl.Color.black);
    switch (shape) {
        PieceShapes.i => {
            const pieceLength = squareSideLength * 4;
            const pieceHeight = squareSideLength;
            const offsetsX = [4]i32{ 0, 1, 2, 3 };
            const offsetsY = [4]i32{ 0, 0, 0, 0 };
            offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
        },
        PieceShapes.j => {
            const pieceLength = squareSideLength * 3;
            const pieceHeight = squareSideLength * 2;
            const offsetsX = [4]i32{ 0, 0, 1, 2 };
            const offsetsY = [4]i32{ 0, 1, 1, 1 };
            offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
        },
        PieceShapes.l => {
            const pieceLength = squareSideLength * 3;
            const pieceHeight = squareSideLength * 2;
            const offsetsX = [4]i32{ 0, 1, 2, 2 };
            const offsetsY = [4]i32{ 1, 1, 1, 0 };
            offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
        },
        PieceShapes.o => {
            const pieceLength = squareSideLength * 2;
            const pieceHeight = squareSideLength * 2;
            const offsetsX = [4]i32{ 0, 1, 0, 1 };
            const offsetsY = [4]i32{ 0, 0, 1, 1 };
            offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
        },
        PieceShapes.s => {
            const pieceLength = squareSideLength * 3;
            const pieceHeight = squareSideLength * 2;
            const offsetsX = [4]i32{ 0, 1, 1, 2 };
            const offsetsY = [4]i32{ 1, 1, 0, 0 };
            offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
        },
        PieceShapes.z => {
            const pieceLength = squareSideLength * 3;
            const pieceHeight = squareSideLength * 2;
            const offsetsX = [4]i32{ 0, 1, 1, 2 };
            const offsetsY = [4]i32{ 0, 0, 1, 1 };
            offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
        },
        PieceShapes.t => {
            const pieceLength = squareSideLength * 3;
            const pieceHeight = squareSideLength * 2;
            const offsetsX = [4]i32{ 0, 1, 1, 2 };
            const offsetsY = [4]i32{ 1, 1, 0, 1 };
            offsetPieceRects(&pieceRects, background, pieceLength, pieceHeight, offsetsX, offsetsY);
        },
    }
    for (pieceRects) |pieceRect| {
        rl.drawRectangleRec(pieceRect, shape.toColor());
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
