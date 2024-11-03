const std = @import("std");
const rl = @import("raylib");
const Rect = @import("rect.zig").Rect;
const Vec2 = @import("vec2.zig").Vec2;

const Self = @This();

const Padding = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
};

min_zoom: f32 = 0.1,
max_zoom: f32 = 10,
padding: Padding = .{},
inner_cam: rl.Camera2D,

pub fn init() Self {
    return .{
        .inner_cam = rl.Camera2D{
            .target = .{ .x = 0, .y = 0 },
            .zoom = 1,
            .rotation = 0,
            .offset = .{ .x = 0, .y = 0 },
        },
    };
}

pub fn begin(self: *Self) void {
    self.inner_cam.begin();
}

pub fn end(self: *Self) void {
    self.inner_cam.end();
}

pub fn getPosition(self: Self) Vec2(f32) {
    return .{
        self.inner_cam.target.x - self.inner_cam.offset.x,
        self.inner_cam.target.y - self.inner_cam.offset.y,
    };
}

/// Converts the viewport into a `Rect`
pub fn getViewport(self: Self, window_size: Vec2(f32)) Rect {
    const zoom_factor: f32 = self.inner_cam.zoom;
    // top_left
    const position: Vec2(f32) = self.getPosition();

    const width = window_size[0] / zoom_factor;
    const height = window_size[1] / zoom_factor;
    return .{
        .position = position,
        .size = .{ width, height },
    };
}

pub fn setViewport(self: *Self, window_size: Vec2(f32), position: Vec2(f32), anchor: Vec2(f32)) void {
    const v = self.getViewport(window_size);
    const offset: rl.Vector2 = .{
        .x = v.size[0] * anchor[0],
        .y = v.size[1] * anchor[1],
    };
    self.inner_cam.target = .{
        .x = position[0],
        .y = position[1],
    };
    self.inner_cam.offset = .{
        .x = offset.x,
        .y = offset.y,
    };
}

// TODO: this one doesn't work yet!
pub fn scaleToViewport(self: *Self, viewport: Rect, padding: Padding) void {
    _ = padding;
    const v = self.getViewport(viewport.size);
    const scale_factor: f32 = v.size[0] / self.inner_cam.zoom;
    const new_zoom = viewport.size[0] * scale_factor;
    self.setZoom(new_zoom);
}

pub fn setZoom(self: *Self, zoom: f32) void {
    var z: f32 = zoom;
    if (z < self.min_zoom) {
        z = self.min_zoom;
    } else if (z > self.max_zoom) {
        z = self.max_zoom;
    }

    self.inner_cam.zoom = z;
}

pub fn zoomStep(self: *Self, step: f32) void {
    const z = self.inner_cam.zoom + step;
    self.setZoom(z);
}
