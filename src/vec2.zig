const std = @import("std");

pub fn randFloat(comptime T: type, rng: std.rand.Random, min: T, max: T) T {
    return rng.float(T) * (max - min) + min;
}

pub fn randInt(comptime T: type, rng: std.rand.Random, min: T, max: T) T {
    return rng.int(T) * (max - min) + min;
}

// VECTOR 2
pub fn Vec2(comptime T: type) type {
    // TODO: check if T is numeric
    return @Vector(2, T);
}

pub fn length2(comptime T: type, vec: Vec2(T)) T {
    return @reduce(.Add, vec * vec);
}

pub fn length(comptime T: type, vec: Vec2(T)) T {
    return std.math.sqrt(length2(T, vec));
}

pub fn distanceTo(comptime T: type, vec1: Vec2(T), vec2: Vec2(T)) T {
    return length(T, vec1 - vec2);
}

pub fn distanceToSquared(comptime T: type, vec1: Vec2(T), vec2: Vec2(T)) T {
    return length2(T, vec1 - vec2);
}

pub fn normalize(comptime T: type, vec: Vec2(T)) Vec2(T) {
    const l = length(T, vec);
    if (l == 0.0) return .{ 0, 0 };
    return vec * @as(Vec2(T), @splat((1 / l)));
}

pub fn lerp(comptime T: type, vec1: Vec2(T), vec2: Vec2(T), t: T) Vec2(T) {
    return vec1 * (1 - t) + vec2 * t;
}

pub fn clampX(comptime T: type, vec: Vec2(T), minX: T, maxX: T) Vec2(T) {
    return .{ std.math.clamp(vec[0], minX, maxX), vec[1] };
}

pub fn clampY(comptime T: type, vec: Vec2(T), minY: T, maxY: T) Vec2(T) {
    return .{ vec[0], std.math.clamp(vec[1], minY, maxY) };
}

pub fn cross(comptime T: type, vec1: Vec2(T), vec2: Vec2(T)) T {
    return vec1[0] * vec2[1] - vec2[0] * vec2[1];
}

pub fn dot(comptime T: type, vec1: Vec2(T), vec2: Vec2(T)) f32 {
    return vec1[0] * vec2[0] + vec1[1] * vec2[1];
}

pub fn rotate(comptime T: type, vec: Vec2(T), rad: T) Vec2(T) {
    const cos_res = std.math.cos(rad);
    const sin_res = std.math.sin(rad);

    return .{
        vec[0] * cos_res - vec[1] * sin_res,
        vec[0] * sin_res + vec[1] * cos_res,
    };
}

pub fn fromAngle(comptime T: type, a: T) Vec2(T) {
    return rotate(T, .{ 1, 0 }, a);
}

pub fn radiansToDegree(rad: f32) f32 {
    return rad * (180.0 / std.math.pi);
}

pub fn angleRadians(comptime T: type, vec: Vec2(T)) T {
    return std.math.atan2(vec[1], vec[0]);
}

pub fn angleDegree(comptime T: type, vec: Vec2(T)) T {
    const rad = angleRadians(T, vec);
    const deg = rad * (180.0 / std.math.pi);
    return deg;
}

// TODO: check for numeric type and either use randomFloat or randomInt
// pub fn randomOnUnitCircle(rng: std.rand.Random) @This() {
//     return (Vector2{ .x = 1 }).rotate(randomF32(rng, -std.math.pi, std.math.pi));
// }
//
// pub fn randomInUnitCircle(comptime: T, rng: std.rand.Random) Vec2(T) {
//     return randomOnUnitCircle(rng).scale(randomF32(rng, 0, 1));
// }
