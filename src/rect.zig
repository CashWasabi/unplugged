const vec2 = @import("vec2.zig");
const Vec2 = vec2.Vec2;

pub const Rect = struct {
    position: Vec2(f32),
    size: Vec2(f32),

    pub fn toI32(self: Rect) RectI {
        return .{
            .position = .{
                @intFromFloat(self.position[0]),
                @intFromFloat(self.position[1]),
            },
            .size = .{
                @intFromFloat(self.size[0]),
                @intFromFloat(self.size[1]),
            },
        };
    }

    // expects 0 to 1!
    pub fn fromAnchor(self: Rect, anchor: Vec2(f32)) Vec2(f32) {
        return self.position + self.size * anchor;
    }

    pub fn topLeft(self: Rect) Vec2(f32) {
        return .{ self.position[0], self.position[1] };
    }

    pub fn topCenter(self: Rect) Vec2(f32) {
        return .{
            self.position[0] + self.size[0] * 0.5,
            self.position[1],
        };
    }

    pub fn topRight(self: Rect) Vec2(f32) {
        return .{
            self.position[0] + self.size[0],
            self.position[1],
        };
    }

    pub fn centerLeft(self: Rect) Vec2(f32) {
        return .{
            self.position[0],
            self.position[1] + self.size[1] * 0.5,
        };
    }

    pub fn center(self: Rect) Vec2(f32) {
        return .{
            self.position[0] + self.size[0] * 0.5,
            self.position[1] + self.size[1] * 0.5,
        };
    }

    pub fn centerRight(self: Rect) Vec2(f32) {
        return .{
            self.position[0] + self.size[0],
            self.position[1] + self.size[1] * 0.5,
        };
    }

    pub fn bottomLeft(self: Rect) Vec2(f32) {
        return .{
            self.position[0],
            self.position[1] + self.size[1],
        };
    }

    pub fn bottomCenter(self: Rect) Vec2(f32) {
        return .{
            self.position[0] + self.size[0] * 0.5,
            self.position[1] + self.size[1],
        };
    }

    pub fn bottomRight(self: Rect) Vec2(f32) {
        return .{
            self.position[0] + self.size[0],
            self.position[1] + self.size[1],
        };
    }

    pub fn area(self: Rect) f32 {
        return self.size[0] * self.size[1];
    }

    pub fn include(self: Rect, other: Rect) Rect {
        return self.includePoint(other.topLeft()).includePoint(other.bottomRight());
    }

    pub fn includePoint(self: Rect, point: Vec2(f32)) Rect {
        const minX = @min(self.position[0], point[0]);
        const minY = @min(self.position[1], point[1]);
        const maxX = @max(self.position[0] + self.size[0], point[0]);
        const maxY = @max(self.position[1] + self.size[1], point[1]);

        return .{
            .position = .{ minX, minY },
            .size = .{ maxX - minY, maxY - minY },
        };
    }

    pub fn collides(self: Rect, other: Rect) bool {
        const self_size = self.size;
        const self_pos = self.position - self_size;
        const other_size = other.size;
        const other_pos = other.position - other_size;

        // zig fmt: off
        return (
            self_pos[0] + self_size[0] >= other_pos[0] and
            self_pos[0] <= other_pos[0] + other_size[0] and
            self_pos[1] + self_size[1] >= other_pos[1] and
            self_pos[1] <= other_pos[1] + other_size[1]
        );
        // zig fmt: on
    }
};

pub const RectI = struct {
    position: Vec2(i32),
    size: Vec2(i32),

    pub fn toF32(self: RectI) Rect {
        return .{
            .position = .{
                @floatFromInt(self.position[0]),
                @floatFromInt(self.position[1]),
            },
            .size = .{
                @floatFromInt(self.size[0]),
                @floatFromInt(self.size[1]),
            },
        };
    }

    pub fn topLeft(self: RectI) Vec2(i32) {
        return .{ self.position[0], self.position[1] };
    }

    pub fn topCenter(self: RectI) Vec2(i32) {
        return .{
            self.position[0] + @divFloor(self.size[0], 2),
            self.position[1],
        };
    }

    pub fn topRight(self: RectI) Vec2(i32) {
        return .{
            self.position[0] + self.size[0],
            self.position[1],
        };
    }

    pub fn centerLeft(self: RectI) Vec2(i32) {
        return .{
            self.position[0],
            self.position[1] + @divFloor(self.size[1], 2),
        };
    }

    pub fn center(self: RectI) Vec2(i32) {
        return .{
            self.position[0] + @divFloor(self.size[0], 2),
            self.position[1] + @divFloor(self.size[1], 2),
        };
    }

    pub fn centerRight(self: RectI) Vec2(i32) {
        return .{
            self.position[0] + self.size[0],
            self.position[1] + @divFloor(self.size[1], 2),
        };
    }

    pub fn bottomLeft(self: RectI) Vec2(i32) {
        return .{
            self.position[0],
            self.position[1] + self.size[1],
        };
    }

    pub fn bottomCenter(self: RectI) Vec2(i32) {
        return .{
            self.position[0] + @divFloor(self.size[0], 2),
            self.position[1] + self.size[1],
        };
    }

    pub fn bottomRight(self: RectI) Vec2(i32) {
        return .{
            self.position[0] + self.size[0],
            self.position[1] + self.size[1],
        };
    }

    pub fn area(self: RectI) i32 {
        return self.size[0] * self.size[1];
    }

    pub fn include(self: RectI, other: RectI) Rect {
        return self.includePoint(other.topLeft()).includePoint(other.bottomRight());
    }

    pub fn includePoint(self: RectI, point: Vec2(i32)) RectI {
        const minX = @min(self.position[0], point[0]);
        const minY = @min(self.position[1], point[1]);
        const maxX = @max(self.position[0] + self.size[0], point[0]);
        const maxY = @max(self.position[1] + self.size[1], point[1]);

        return .{
            .position = .{ minX, minY },
            .size = .{ maxX - minY, maxY - minY },
        };
    }

    pub fn collides(self: RectI, other: RectI) bool {
        const self_size = self.size;
        const self_pos = self.position - self_size;
        const other_size = other.size;
        const other_pos = other.position - other_size;

        // zig fmt: off
        return (
            self_pos[0] + self_size[0] >= other_pos[0] and
            self_pos[0] <= other_pos[0] + other_size[0] and
            self_pos[1] + self_size[1] >= other_pos[1] and
            self_pos[1] <= other_pos[1] + other_size[1]
        );
        // zig fmt: on
    }
};
