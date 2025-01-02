const std = @import("std");
const rl = @import("raylib");

pub const Timer = struct {
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
