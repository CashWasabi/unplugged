const rl = @import("raylib");

const Vec2 = @import("vec2.zig").Vec2;
const Rect = @import("rect.zig").Rect;

const Self = @This();

texture: rl.Texture2D,

pub fn getTileRect(self: Self, position: Vec2(f32), scale: Vec2(f32), origin: Vec2(f32)) Rect {
    const width = @as(f32, @floatFromInt(self.texture.width)) * scale[0];
    const height = @as(f32, @floatFromInt(self.texture.height)) * scale[1];
    const x = position[0] - width * origin[0];
    const y = position[1] - height * origin[1];
    return .{
        .position = .{ x, y },
        .size = .{ width, height },
    };
}

pub fn getTileSize(self: Self, scale: Vec2(f32)) Vec2(f32) {
    const size: Vec2(f32) = .{
        @floatFromInt(self.texture.width),
        @floatFromInt(self.texture.height),
    };
    return size * scale;
}

pub fn draw(
    self: Self,
    position: Vec2(f32),
    scale: Vec2(f32),
    anchor: Vec2(f32),
    rotation: f32, // in degree
    tint: rl.Color,
) void {
    const source = rl.Rectangle{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(self.texture.width),
        .height = @floatFromInt(self.texture.height),
    };

    const size_scaled: Vec2(f32) = .{
        source.width * scale[0],
        source.height * scale[1],
    };
    const dest = rl.Rectangle{
        .x = position[0],
        .y = position[1],
        .width = size_scaled[0],
        .height = size_scaled[1],
    };
    const origin: rl.Vector2 = .{ .x = size_scaled[0] * anchor[0], .y = size_scaled[1] * anchor[1] };
    rl.drawTexturePro(self.texture, source, dest, origin, rotation, tint);
}
