const std = @import("std");
const rl = @import("raylib");
const Scene = @import("scene.zig").Scene;
const Context = @import("Context.zig");

const Self = @This();

allocator: std.mem.Allocator,
scenes: std.ArrayListUnmanaged(Scene) = .{},
stack: std.ArrayListUnmanaged(Scene) = .{},
active_scene_idx: usize = 0,
active_scene: Scene = undefined,
should_quit: bool = false,

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Self, ctx: *Context) void {
    for (self.stack.items) |*s| s.deinit(ctx);
    self.stack.deinit(self.allocator);

    for (self.scenes.items) |*s| s.deinit(ctx);
    self.scenes.deinit(self.allocator);
}

inline fn numScenes(self: *Self) usize {
    return self.scenes.items.len;
}

pub fn add(self: *Self, ctx: *Context, scene: Scene) !usize {
    try scene.init(ctx);
    try self.scenes.append(self.allocator, scene);
    return self.scenes.items.len - 1;
}

pub fn next(self: *Self, ctx: *Context) !void {
    self.scenes.items[self.active_scene_idx].deinit(ctx);

    if (self.active_scene_idx + 1 >= self.numScenes()) {
        self.active_scene_idx = 0;
    } else {
        self.active_scene_idx += 1;
    }

    try self.scenes.items[self.active_scene_idx].init(ctx);
}

pub fn goto(self: *Self, ctx: *Context, s: usize) !void {
    std.debug.assert(s < self.numScenes());
    self.scenes.items[self.active_scene_idx].deinit(ctx);

    self.active_scene_idx = s;
    try self.scenes.items[s].init(ctx);
}

pub fn draw(self: *Self, ctx: *Context) !void {
    const active_scene_idx = self.active_scene_idx;
    try self.scenes.items[active_scene_idx].draw(ctx);
    if (self.scenes.items[active_scene_idx].isFinished()) {
        try self.next(ctx);
    }
}

pub fn update(self: *Self, ctx: *Context) !void {
    const active_scene_idx = self.active_scene_idx;
    try self.scenes.items[active_scene_idx].update(ctx);
    if (self.scenes.items[active_scene_idx].isFinished()) {
        try self.next(ctx);
    }
}

pub fn shouldQuit(self: *Self) bool {
    return rl.WindowShouldClose() or self.should_quit;
}

test "scene manager test" {
    return error.SkipZigTest;
}
