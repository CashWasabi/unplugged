const std = @import("std");
const rl = @import("raylib");

const helpers = @import("helpers.zig");

const Cam = @import("Cam.zig");
const Window = @import("Window.zig");
const Context = @import("Context.zig");
const GlobalData = @import("world.zig").GlobalData;
const AssetLoader = @import("AssetLoader.zig");
const SceneSystem = @import("SceneSystem.zig");
const Vec2 = @import("vec2.zig").Vec2;

const Self = @This();

allocator: std.mem.Allocator,

cam: Cam,
window: Window,
scene_system: SceneSystem,
assets: AssetLoader,
game_data: GlobalData,

pub fn init(allocator: std.mem.Allocator, window_size: Vec2(f32), fps: i32) !Self {
    return .{
        .allocator = allocator,
        .assets = .{ .allocator = allocator },
        .scene_system = try SceneSystem.init(allocator),
        .window = Window.init(allocator, .{ window_size[0], window_size[1] }, fps),
        .cam = Cam.init(),
        .game_data = .{},
    };
}

pub fn deinit(self: *Self) void {
    self.scene_system.deinit(self);
    self.assets.deinit();
}
