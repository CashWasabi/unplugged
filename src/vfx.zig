const std = @import("std");
const rl = @import("raylib");
const helpers = @import("helpers.zig");
const Vec2 = @import("vec2.zig").Vec2;
const SpriteSheet = @import("SpriteSheet.zig");

const Direction = enum { forward, reverse };
const EffectType = enum { once, repeat, ping_pong };
pub const SpriteSheetVFX = struct {
    active_tile: usize = 0,
    delta_frames: usize = 0,
    fps: usize = 30,
    direction: Direction = .forward,
    effect_type: EffectType = .once,
    spritesheet_ptr: *SpriteSheet,

    pub fn init(
        spritesheet_ptr: *SpriteSheet,
        opts: struct {
            fps: usize = 30,
            direction: Direction = .forward,
            effect_type: EffectType = .once,
        },
    ) SpriteSheetVFX {
        const max_frames: usize = spritesheet_ptr.grid[0] * spritesheet_ptr.grid[1];
        return .{
            .active_tile = if (opts.direction == .forward) 0 else max_frames - 1,
            .fps = opts.fps,
            .effect_type = opts.effect_type,
        };
    }

    pub fn reset(self: SpriteSheetVFX) void {
        self.active_frame = 0;
    }

    pub fn update(self: SpriteSheetVFX) void {
        self.delta_frames += 1;
        if (self.delta_frames < self.fps) return;
        self.delta_frames = 0;

        const max_frames = self.spritesheet_ptr.grid[0] * self.spritesheet_ptr.grid[1];
        switch (self.effect_type) {
            .once => {
                switch (self.direction) {
                    .forward => {
                        if (self.active_frame < max_frames - 1) self.active_tile += 1;
                    },
                    .reverse => {
                        if (self.active_frame > 0) self.active_tile -= 1;
                    },
                }
            },
            .repeat => {
                switch (self.direction) {
                    .forward => {
                        if (self.active_frame <= max_frames - 1) {
                            self.active_tile += 1;
                        } else {
                            self.active_tile = 0;
                        }
                    },
                    .reverse => {
                        if (self.active_frame > 0) {
                            self.active_tile -= 1;
                        } else {
                            self.active_tile = max_frames - 1;
                        }
                    },
                }
            },
            .ping_pong => {
                switch (self.direction) {
                    .forward => {
                        if (self.active_frame <= max_frames - 1) {
                            self.active_tile += 1;
                        } else {
                            self.direction = .reverse;
                        }
                    },
                    .reverse => {
                        if (self.active_frame > 0) {
                            self.active_tile -= 1;
                        } else {
                            self.direction = .forward;
                        }
                    },
                }
            },
        }
    }
};

// screen shake
pub const ScreenShakeVFX = struct {
    max_frames: usize = 0,
    frames: ?usize = 0,
    origin_position: Vec2(f32) = .{ 0, 0 },
    distortion: Vec2(f32) = .{ 1, 1 },

    pub fn start(
        self: *ScreenShakeVFX,
        frames: usize,
        origin_position: Vec2(f32),
    ) void {
        self.frames = frames;
        self.origin_position = origin_position;
    }

    pub fn update(self: *ScreenShakeVFX, cam_pos: *rl.Vector2) void {
        if (self.frames == null) return;
        if (self.frames.? <= 0) {
            cam_pos.* = .{
                .x = self.origin_position[0],
                .y = self.origin_position[1],
            };
            self.frames = null;
            return;
        }

        const x: f32 = @floatFromInt(helpers.randomRangeI32(-3, 3));
        const y: f32 = @floatFromInt(helpers.randomRangeI32(-3, 3));
        const random_position: rl.Vector2 = .{
            .x = self.origin_position[0] + x,
            .y = self.origin_position[1] + y,
        };
        cam_pos.* = random_position;
        self.frames.? -= 1;
    }
};
