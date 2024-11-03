const std = @import("std");
const rl = @import("raylib");
const Vec2 = @import("vec2.zig").Vec2;
const rect = @import("rect.zig");
const Rect = rect.Rect;
const RectI = rect.RectI;
const AssetLoader = @import("AssetLoader.zig");

const Self = @This();

texture: rl.Texture2D,
grid: Vec2(u32),
spacing: Vec2(u32) = .{ 0, 0 },

pub fn fromTileSize(texture: rl.Texture2D, tile_size: Vec2(u32), spacing: Vec2(u32)) Self {
    const texture_size: Vec2(u32) = .{ @intCast(texture.width), @intCast(texture.height) };
    const grid: Vec2(u32) = @divFloor(texture_size, tile_size + spacing);
    return .{ .texture = texture, .grid = grid, .spacing = spacing };
}

pub fn getTileSize(self: Self, scale: Vec2(f32)) Vec2(u32) {
    const texture_size: Vec2(u32) = .{
        @intCast(self.texture.width),
        @intCast(self.texture.height),
    };
    const tile_size: Vec2(u32) = @divFloor(texture_size, self.grid);
    const tile_size_f32: Vec2(f32) = @floatFromInt(tile_size - self.spacing);
    const tile_size_scaled: Vec2(f32) = tile_size_f32 * scale;
    return @intFromFloat(tile_size_scaled);
}

pub fn _getTileRl(self: Self, sprite_idx: u32) rl.Rectangle {
    const idx_y: u32 = @divFloor(sprite_idx, self.grid[0]);
    const idx_x: u32 = sprite_idx - self.grid[0] * idx_y;
    const tile_size: Vec2(u32) = self.getTileSize(.{ 1, 1 });
    const tile_position: Vec2(u32) = .{
        (tile_size[0] + self.spacing[0]) * idx_x,
        (tile_size[1] + self.spacing[1]) * idx_y,
    };

    return .{
        .x = @floatFromInt(tile_position[0]),
        .y = @floatFromInt(tile_position[1]),
        .width = @floatFromInt(tile_size[0] - self.spacing[0]),
        .height = @floatFromInt(tile_size[1] - self.spacing[1]),
    };
}

pub fn draw(
    self: Self,
    position: Vec2(f32),
    scale: Vec2(f32),
    anchor: Vec2(f32),
    rotation: f32, // in degree
    tile_idx: u32,
    tint: rl.Color,
) void {
    const source = self._getTileRl(tile_idx);
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
