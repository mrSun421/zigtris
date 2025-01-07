pub const RotationState = enum {
    Zero,
    Right,
    Two,
    Left,
    pub fn rotateRight(self: RotationState) RotationState {
        switch (self) {
            .Zero => {
                return RotationState.Right;
            },
            .Right => {
                return RotationState.Two;
            },

            .Two => {
                return RotationState.Left;
            },
            .Left => {
                return RotationState.Zero;
            },
        }
    }
    pub fn rotateLeft(self: RotationState) RotationState {
        switch (self) {
            .Zero => {
                return RotationState.Left;
            },
            .Right => {
                return RotationState.Zero;
            },

            .Two => {
                return RotationState.Right;
            },
            .Left => {
                return RotationState.Two;
            },
        }
    }
};
