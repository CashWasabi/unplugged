const std = @import("std");
const rl = @import("raylib");
const Vec2 = @import("vec2.zig").Vec2;
const Rect = @import("rect.zig").Rect;
const configs = @import("configs.zig");

const Self = @This();

allocator: std.mem.Allocator,
target_fps: i32 = 0,
size: Vec2(f32),

pub fn init(allocator: std.mem.Allocator, size: Vec2(f32), target_fps: i32) Self {
    rl.initWindow(
        @as(i32, @intFromFloat(size[0])),
        @as(i32, @intFromFloat(size[1])),
        configs.title,
    );
    rl.setTargetFPS(target_fps);

    return .{
        .allocator = allocator,
        .target_fps = target_fps,
        .size = .{ size[0], size[1] },
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
    rl.closeWindow();
}

pub fn resize(self: *Self) void {
    self.size = .{
        @floatFromInt(rl.getScreenWidth()),
        @floatFromInt(rl.getScreenHeight()),
    };
}

pub fn toRect(self: *Self) Rect {
    return .{
        .position = .{ 0, 0 },
        .size = .{ self.size[0], self.size[1] },
    };
}
