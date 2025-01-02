const std = @import("std");
var prng = std.Random.DefaultPrng.init(0);
const PieceShape = @import("pieceShape.zig").PieceShape;

const pieceCount = 7;

pub const PieceQueue = struct {
    slice: [pieceCount]PieceShape,
    start: usize,
    len: usize,
    bag: std.bit_set.IntegerBitSet(pieceCount),
    pub fn init() PieceQueue {
        var q = PieceQueue{
            .slice = [_]PieceShape{@enumFromInt(0)} ** pieceCount,
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

    pub fn enqueue(self: *PieceQueue, shape: PieceShape) void {
        if (self.len >= pieceCount) {
            return;
        }
        const end = (self.start + self.len) % pieceCount;

        self.slice[end] = shape;
        self.len += 1;
    }
    pub fn dequeue(self: *PieceQueue) PieceShape {
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

    pub fn getFront(self: *PieceQueue) PieceShape {
        return self.slice[self.start];
    }
};
