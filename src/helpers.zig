const std = @import("std");
const rl = @import("raylib");
const RndGen = std.rand.DefaultPrng;
const Vec2 = @import("vec2.zig").Vec2;
const configs = @import("configs.zig");

var rnd = RndGen.init(configs.seed);

pub fn colorToI32(color: rl.Color) i32 {
    var rgb: i32 = color.r;
    rgb = (rgb << 8) + color.g;
    rgb = (rgb << 8) + color.b;
    rgb = (rgb << 8) + color.a;

    return rgb;
}

pub fn randomF32() f32 {
    return rnd.random().float(f32);
}

pub fn randomI32() i32 {
    return rnd.random().int(i32);
}

pub fn randomRangeI32(min: i32, max: i32) i32 {
    return rnd.random().intRangeLessThan(i32, min, max);
}

pub fn randomRangeF32(min: i32, max: i32) f32 {
    return @floatFromInt(rnd.random().intRangeLessThan(i32, min, max));
}

pub const Ratio = enum {
    _1x1,
    _1x2,
    _2x1,
    _4x3,
    _3x4,
    _16x9,
    _9x16,
    _16x10,
    _10x16,
};

pub const AlignedBy = enum {
    width,
    height,
};

// https://en.wikipedia.org/wiki/Display_resolution
pub const Resolution = struct {
    pub fn maxResolution() Vec2(f32) {
        return .{
            @floatFromInt(rl.getScreenWidth()),
            @floatFromInt(rl.getScreenHeight()),
        };
    }

    // ==================
    // MOBILE resolutions
    // ==================
    // Mobile Horizontal min res
    pub fn mb960p() Vec2(f32) {
        return .{ 540, 960 };
    }

    // ==============
    // ITCH.io
    // ==============

    pub fn itchIOp() Vec2(f32) {
        return .{ 800, 450 };
    }
    // ==============
    // PC resolutions
    // ==============
    pub fn pc360p() Vec2(f32) {
        return .{ 640, 360 };
    }

    pub fn pc480p() Vec2(f32) {
        return .{ 720, 480 };
    }

    pub fn pc576p() Vec2(f32) {
        return .{ 720, 576 };
    }

    pub fn pc720p() Vec2(f32) {
        return .{ 1280, 720 };
    }

    pub fn pc1080p() Vec2(f32) {
        return .{ 1920, 1080 };
    }

    pub fn pc4k() Vec2(f32) {
        return .{ 1440, 2560 };
    }

    pub fn pc4kUHD() Vec2(f32) {
        return .{ 3840, 2160 };
    }

    pub fn pc8kUHD() Vec2(f32) {
        return .{ 7680, 4320 };
    }
};
