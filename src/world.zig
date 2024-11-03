const std = @import("std");
const rl = @import("raylib");

const Context = @import("Context.zig");
const AssetLoader = @import("AssetLoader.zig");

const configs = @import("configs.zig");
const gui = @import("gui.zig");
const scene = @import("scene.zig");
const vec2 = @import("vec2.zig");
const Vec2 = vec2.Vec2;
const rect = @import("rect.zig");
const Rect = rect.Rect;
const RectI = rect.RectI;
const SpriteSheet = @import("SpriteSheet.zig");

const generics = @import("generics.zig");
const Grid = generics.Grid;
const BoundedGrid = generics.BoundedGrid;

const helpers = @import("helpers.zig");
const sfx = @import("sfx.zig");

// ================
// HELPER FUNCTIONS
// ================
// TODO: we actally need to take zoom into account for mouse position here!
pub fn mouseToWorldPosition(view_rec: Rect) Vec2(f32) {
    const mouse_pos: Vec2(i32) = .{ rl.getMouseX(), rl.getMouseY() };
    const new_pos_f32: Vec2(f32) = .{
        view_rec.position[0] + @as(f32, @floatFromInt(mouse_pos[0])),
        view_rec.position[1] + @as(f32, @floatFromInt(mouse_pos[1])),
    };
    return new_pos_f32;
}

pub fn isNeighbour(coords: Vec2(i32), other_coords: Vec2(i32)) bool {
    const delta = coords - other_coords;
    if (delta[0] == 0 and delta[1] == 0) return false; // same coords
    if (@abs(delta[0]) > 1 or @abs(delta[1]) > 1) return false; // too far away
    if (@abs(delta[0]) == 1 and @abs(delta[1]) == 1) return false; // no diagonals
    return true;
}

// ========
// STRUCTS
// ========
pub const GlobalData = struct {
    turns: usize = 0,

    pub fn reset(self: *GlobalData) void {
        self.turns = 0;
    }
};

pub const WorldSprite = enum {
    horizontal_pipe,
    vertical_pipe,
    down_right_pipe,
    corner_pipe,

    plug_off,
    plug_on,

    connector_on,
    connector_off,

    cutter,

    obstacle,

    unknown,

    pub fn fromSpriteIdx(idx: u32) WorldSprite {
        return switch (idx) {
            228 => .horizontal_pipe,
            247 => .vertical_pipe,
            267 => .corner_pipe,

            7 => .plug_on,
            27 => .plug_off,

            28 => .connector_off,
            8 => .connector_on,

            264 => .cutter,

            11 => .obstacle,

            else => .unknown,
        };
    }

    pub inline fn toSpriteIdx(self: WorldSprite) u32 {
        return switch (self) {
            .horizontal_pipe => 228,
            .vertical_pipe => 247,
            .corner_pipe => 267,

            .plug_on => 7,
            .plug_off => 27,

            .connector_on => 8,
            .connector_off => 28,

            .cutter => 264,

            .obstacle => 11,

            else => 0,
        };
    }

    // TODO: use same with options
    pub inline fn toSpriteIdxValues() []const u32 {
        comptime {
            const land_sprites = std.enums.values(WorldSprite);
            var indices: [@typeInfo(WorldSprite).Enum.fields.len]u32 = undefined;

            for (0.., land_sprites) |i, land_sprite| {
                indices[i] = land_sprite.toSpriteIdx();
            }
            const final = indices;
            return &final;
        }
    }
};

pub const PipeLine = struct {
    start_plug_coords: Vec2(u32),
    end_plug_coords: Vec2(u32),

    max_piece_length: u32,
    pieces: std.ArrayList(Vec2(u32)), // list of positions

    pub fn init(
        allocator: std.mem.Allocator,
        start_plug_coords: Vec2(u32),
        end_plug_coords: Vec2(u32),
        max_piece_length: u32,
    ) PipeLine {
        return .{
            .start_plug_coords = start_plug_coords,
            .end_plug_coords = end_plug_coords,
            .max_piece_length = max_piece_length,
            .pieces = std.ArrayList(Vec2(u32)).init(allocator),
        };
    }

    pub fn deinit(self: PipeLine) void {
        self.pieces.deinit();
    }

    // ===================
    // field related stuff
    // ===================
    pub fn addPiece(self: *PipeLine, field_ptr: *Field, coords: Vec2(u32)) !void {
        // remove all previously rendered pieces and render new
        if (!self.isTailNeighbour(coords)) return;
        if (self.pieces.items.len >= self.max_piece_length) return;
        self.removeFromField(field_ptr);
        try self.pieces.append(coords);
        self.applyToField(field_ptr);
    }

    pub fn removeAllPieces(self: *PipeLine, field_ptr: *Field) void {
        self.removeFromField(field_ptr);
        self.pieces.clearRetainingCapacity();
        self.applyToField(field_ptr);
    }

    pub fn removeTailPiece(self: *PipeLine, field_ptr: *Field) void {
        if (self.pieces.items.len == 0) return;
        self.removeFromField(field_ptr);
        _ = self.pieces.popOrNull();
        self.applyToField(field_ptr);
    }

    pub fn applyToField(self: PipeLine, field_ptr: *Field) void {
        const is_connected = self.isConnected();
        for (0.., self.pieces.items) |idx, coords| {
            var grid_tile = self._getGridTileFromPieceIdx(idx).?;
            if (is_connected) {
                grid_tile.tint = rl.Color.white;
            } else {
                grid_tile.tint.a = 128;
            }
            _ = field_ptr.grid.set(coords[0], coords[1], grid_tile);
        }
    }

    pub fn removeFromField(self: PipeLine, field_ptr: *Field) void {
        for (self.pieces.items) |coords| {
            _ = field_ptr.grid.set(
                coords[0],
                coords[1],
                .{ .sprite_idx = WorldSprite.toSpriteIdx(.unknown) },
            );
        }
    }

    // ===================
    // INTERNAL STUFF
    // ===================
    pub fn isPipePiece(self: PipeLine, coords: Vec2(u32)) bool {
        for (self.pieces.items) |piece_coords| {
            if (coords[0] == piece_coords[0] and
                coords[1] == piece_coords[1])
            {
                return true;
            }
        }
        if (coords[0] == self.start_plug_coords[0] and
            coords[1] == self.start_plug_coords[1])
        {
            return true;
        }
        if (coords[0] == self.end_plug_coords[0] and
            coords[1] == self.end_plug_coords[1])
        {
            return true;
        }

        return false;
    }

    pub fn isTailNeighbour(self: PipeLine, coords: Vec2(u32)) bool {
        var tail_coords = self.start_plug_coords;
        if (self.pieces.items.len > 0) {
            tail_coords = self.pieces.items[self.pieces.items.len - 1];
        }
        return isNeighbour(
            .{ @intCast(coords[0]), @intCast(coords[1]) },
            .{ @intCast(tail_coords[0]), @intCast(tail_coords[1]) },
        );
    }

    pub fn isPieceBeforeTailPiece(self: PipeLine, coords: Vec2(u32)) bool {
        var target_coords = self.start_plug_coords;
        if (self.pieces.items.len > 1) {
            target_coords = self.pieces.items[self.pieces.items.len - 2];
        }

        return coords[0] == target_coords[0] and coords[1] == target_coords[1];
    }

    pub fn isConnected(self: PipeLine) bool {
        if (self.pieces.items.len == 0) return false;

        const end_plug_coords = self.end_plug_coords;
        const tail_coords = self.pieces.items[self.pieces.items.len - 1];
        return isNeighbour(
            .{ @intCast(tail_coords[0]), @intCast(tail_coords[1]) },
            .{ @intCast(end_plug_coords[0]), @intCast(end_plug_coords[1]) },
        );
    }

    fn _getGridTileFromPieceIdx(self: PipeLine, idx: usize) ?GridTile {
        const prev_n_dir = self._getPrevNeighbourDirection(idx);

        if (self._isCorner(idx)) {
            const maybe_next_n_dir = self._getNextNeighbourDirection(idx);
            if (maybe_next_n_dir) |next_n_dir| {
                const corner_pipe_idx = WorldSprite.toSpriteIdx(.corner_pipe);
                if (prev_n_dir[1] == -1 and next_n_dir[0] == 1 or
                    prev_n_dir[0] == 1 and next_n_dir[1] == -1)
                { // top_to_right
                    return .{
                        .sprite_idx = corner_pipe_idx,
                        .rotation = .down,
                    };
                } else if (prev_n_dir[0] == 1 and next_n_dir[1] == 1 or
                    prev_n_dir[1] == 1 and next_n_dir[0] == 1)
                { // right_to_bottom
                    return .{
                        .sprite_idx = corner_pipe_idx,
                        .rotation = .left,
                    };
                } else if (prev_n_dir[1] == 1 and next_n_dir[0] == -1 or
                    prev_n_dir[0] == -1 and next_n_dir[1] == 1)
                { // bottom_to_left
                    return .{
                        .sprite_idx = corner_pipe_idx,
                        .rotation = .up,
                    };
                } else if (prev_n_dir[0] == -1 and next_n_dir[1] == -1 or
                    prev_n_dir[1] == -1 and next_n_dir[0] == -1)
                { // left_to_top
                    return .{
                        .sprite_idx = corner_pipe_idx,
                        .rotation = .right,
                    };
                }
            }
        }
        if (prev_n_dir[1] != 0) return .{ .sprite_idx = WorldSprite.toSpriteIdx(.vertical_pipe) }; // top/bottom
        if (prev_n_dir[0] != 0) return .{ .sprite_idx = WorldSprite.toSpriteIdx(.horizontal_pipe) }; // right/left

        return .{ .sprite_idx = WorldSprite.toSpriteIdx(.obstacle) }; // shouldn't happen!
    }

    fn _getNextNeighbourDirection(self: PipeLine, piece_idx: usize) ?Vec2(i32) {
        std.debug.assert(piece_idx < self.pieces.items.len);

        const coords = self.pieces.items[piece_idx];
        var maybe_next_coords: ?Vec2(u32) = null;

        // TODO: maybe return end_plug_coords
        if (piece_idx + 1 > self.pieces.items.len - 1) {
            if (self.isConnected()) {
                maybe_next_coords = self.end_plug_coords;
            }
        } else {
            maybe_next_coords = self.pieces.items[piece_idx + 1];
        }

        if (maybe_next_coords) |next_coords| {
            const coords_i32: Vec2(i32) = .{ @intCast(coords[0]), @intCast(coords[1]) };
            const next_coords_i32: Vec2(i32) = .{ @intCast(next_coords[0]), @intCast(next_coords[1]) };

            return coords_i32 - next_coords_i32;
        }

        return null;
    }

    fn _getPrevNeighbourDirection(self: PipeLine, piece_idx: usize) Vec2(i32) {
        std.debug.assert(piece_idx < self.pieces.items.len);

        const coords = self.pieces.items[piece_idx];
        var prev_coords: Vec2(u32) = undefined;

        if (piece_idx == 0) {
            prev_coords = self.start_plug_coords;
        } else {
            prev_coords = self.pieces.items[piece_idx - 1];
        }

        const coords_i32: Vec2(i32) = .{ @intCast(coords[0]), @intCast(coords[1]) };
        const prev_coords_i32: Vec2(i32) = .{ @intCast(prev_coords[0]), @intCast(prev_coords[1]) };

        return coords_i32 - prev_coords_i32;
    }

    fn _isCorner(self: PipeLine, piece_idx: usize) bool {
        std.debug.assert(piece_idx < self.pieces.items.len);

        const coords = self.pieces.items[piece_idx];
        var maybe_next_coords: ?Vec2(u32) = null;
        var prev_coords: Vec2(u32) = self.start_plug_coords;
        if (piece_idx > 0) {
            if (piece_idx + 1 == self.pieces.items.len) {
                if (self.isConnected()) {
                    maybe_next_coords = self.end_plug_coords;
                    prev_coords = self.pieces.items[piece_idx - 1];
                } else {
                    prev_coords = self.pieces.items[piece_idx - 1];
                }
            } else {
                maybe_next_coords = self.pieces.items[piece_idx + 1];
                prev_coords = self.pieces.items[piece_idx - 1];
            }
        } else {
            if (self.pieces.items.len > 1) {
                maybe_next_coords = self.pieces.items[piece_idx + 1];
            }
        }

        // if not all in same row or same col then we have a corner
        if (maybe_next_coords) |next_coords| {
            const same_col = prev_coords[0] == coords[0] and coords[0] == next_coords[0];
            const same_row = prev_coords[1] == coords[1] and coords[1] == next_coords[1];
            if (same_row) return false;
            if (same_col) return false;
            return true;
        }

        return false;
    }
};

pub const Cursor = struct {
    anchor: Vec2(f32) = .{ 0.5, 0.5 },
    last_position: Vec2(i32) = .{ 0, 0 },
    last_field_position: Vec2(u32) = .{ 0, 0 },

    pub fn draw(self: Cursor, field: Field, view_rec: Rect) void {
        // debug draw (how it should be)
        {
            // debug draw field bounds
            {
                // draw outlines of render rect
                const field_render_rect = field.toRenderRect(configs.field_scale);
                rl.drawRectangleLinesEx(
                    .{
                        .x = field_render_rect.position[0],
                        .y = field_render_rect.position[1],
                        .width = field_render_rect.size[0],
                        .height = field_render_rect.size[1],
                    },
                    5,
                    rl.Color.yellow,
                );

                // draw rect at grid rect top_left
                const tile_size_u32: Vec2(u32) = field.spritesheet_ptr.getTileSize(configs.field_scale);
                const tile_size_f32: Vec2(f32) = @floatFromInt(tile_size_u32);
                const field_grid_rect = field.toRenderRect(configs.field_scale);
                const field_grid_rect_top_left = field_grid_rect.topLeft();
                rl.drawRectangleRec(.{
                    .x = field_grid_rect_top_left[0],
                    .y = field_grid_rect_top_left[1],
                    .width = tile_size_f32[0],
                    .height = tile_size_f32[1],
                }, rl.Color.pink);
            }

            // debug draw cursor
            {
                const tile_size_u32: Vec2(u32) = field.spritesheet_ptr.getTileSize(configs.field_scale);
                const tile_size_f32: Vec2(f32) = @floatFromInt(tile_size_u32);
                const view_top_left: Vec2(f32) = view_rec.topLeft() - tile_size_f32 * self.anchor;

                const maybe_mouse_position = self.getWorldPosition(view_rec);
                if (maybe_mouse_position) |mouse_position| {
                    const mouse_position_f32: Vec2(f32) = @floatFromInt(mouse_position);

                    const mouse_position_aligned_u32: Vec2(u32) = @intFromFloat(mouse_position_f32 - view_top_left);
                    const mouse_position_tiled_u32: Vec2(u32) = @divFloor(mouse_position_aligned_u32, tile_size_u32) * tile_size_u32;
                    const mouse_position_tiled_f32: Vec2(f32) = @floatFromInt(mouse_position_tiled_u32);
                    const position: Vec2(f32) = view_top_left + mouse_position_tiled_f32;
                    rl.drawRectanglePro(
                        .{
                            .x = position[0],
                            .y = position[1],
                            .width = tile_size_f32[0],
                            .height = tile_size_f32[1],
                        },
                        .{ .x = 0, .y = 0 },
                        0,
                        rl.Color.orange,
                    );
                }
            }
        }

        // TODO: fix broken draw for uneven grid
        //       (should also work for even then)
        // is not aligned to normal our grid!
        // but just calculated as is
        // IS:        (x) ==  0 | 16 | 16 | 32 | 48
        // SHOULD BE: (x) == -8 | 8  | 24 | 24 | 40
        // When we change the origin!
        {
            const maybe_coords = self.getFieldCoords(field, view_rec);
            if (maybe_coords) |coords| {
                // TODO: is using configs here a good idea?
                const render_rect = field.toRenderRect(configs.field_scale);
                const tile_size_u32 = field.spritesheet_ptr.getTileSize(configs.field_scale);

                const tile_size_f32: Vec2(f32) = @floatFromInt(tile_size_u32);
                const top_left_f32: Vec2(f32) = render_rect.topLeft();

                const coords_f32: Vec2(f32) = @floatFromInt(coords);
                const coords_sized: Vec2(f32) = top_left_f32 + coords_f32 * tile_size_f32;
                rl.drawRectangleLinesEx(
                    .{
                        .x = coords_sized[0],
                        .y = coords_sized[1],
                        .width = tile_size_f32[0],
                        .height = tile_size_f32[1],
                    },
                    3,
                    rl.Color.red,
                );
            }
        }
    }

    pub fn getWorldPosition(self: Cursor, view_rec: Rect) ?Vec2(i32) {
        _ = self;
        if (!rl.isCursorOnScreen()) return null;
        return @intFromFloat(mouseToWorldPosition(view_rec));
    }

    pub fn getFieldCoords(self: Cursor, field: Field, view_rec: Rect) ?Vec2(u32) {
        var view_rec_aligned = view_rec;
        const tile_size_u32 = field.spritesheet_ptr.getTileSize(configs.field_scale);
        const tile_size_i32: Vec2(i32) = @intCast(tile_size_u32);
        view_rec_aligned.position += @as(Vec2(f32), @floatFromInt(tile_size_i32)) * self.anchor;

        const maybe_mouse_position = self.getWorldPosition(view_rec_aligned);

        if (maybe_mouse_position) |mouse_position| {
            if (!field.inRenderRectBounds(@floatFromInt(mouse_position))) return null;

            const mouse_position_aligned: Vec2(i32) = @divFloor(mouse_position, tile_size_i32);

            const grid_rec = field.toGridRect();
            const top_left: Vec2(i32) = grid_rec.topLeft();
            const coords = mouse_position_aligned - top_left;
            return @intCast(coords);
        }

        return null;
    }
};

// 0, 90, 180, 270 degrees
const RotationType = enum {
    up,
    right,
    down,
    left,

    pub inline fn toDegrees(self: RotationType) f32 {
        return switch (self) {
            .up => 0,
            .right => 90,
            .down => 180,
            .left => 270,
        };
    }
};
pub const Tile = struct {
    sprite_idx: u32,
    coords: Vec2(u32),
    rotation: RotationType = .up,
};
pub const GridTile = struct {
    sprite_idx: u32,
    anchor: Vec2(f32) = .{ 0.5, 0.5 },
    rotation: RotationType = .up,
    tint: rl.Color = rl.Color.white,
};
pub const TileList = std.ArrayList(Tile);
pub const TileGrid = Grid(GridTile);
pub const ColliderGrid = Grid(bool);
pub const SpriteGrid = Grid(u32);
pub const PipeLineList = std.ArrayList(PipeLine);
pub const Field = struct {
    position: Vec2(i32),
    origin: Vec2(f32),
    spritesheet_ptr: *SpriteSheet,
    grid: TileGrid,
    collider_grid: ColliderGrid,
    end_plug_list: TileList,
    start_plug_list: TileList,
    connector_list: TileList,
    cutter_list: TileList,
    pipe_line_list: PipeLineList,

    pub fn deinit(self: *Field) void {
        self.grid.deinit();

        self.end_plug_list.deinit();
        self.start_plug_list.deinit();
        self.connector_list.deinit();
        self.cutter_list.deinit();
        self.collider_grid.deinit();

        for (self.pipe_line_list.items) |*i| i.deinit();
        self.pipe_line_list.deinit();
    }

    // ==============
    // === CHECKS ===
    // ==============
    pub fn inGridRectBounds(self: Field, position: Vec2(i32)) bool {
        const rec = self.toGridRect();
        const top_left = rec.topLeft();
        const bottom_right = rec.bottomRight();

        return position[0] >= top_left[0] and
            position[0] < bottom_right[0] and
            position[1] >= top_left[1] and
            position[1] < bottom_right[1];
    }

    pub fn inRenderRectBounds(self: Field, position: Vec2(f32)) bool {
        const rec = self.toRenderRect(configs.field_scale);
        const top_left = rec.topLeft();
        const bottom_right = rec.bottomRight();

        return position[0] >= top_left[0] and
            position[0] < bottom_right[0] and
            position[1] >= top_left[1] and
            position[1] < bottom_right[1];
    }

    // ============
    // === DRAW ===
    // ============
    pub fn draw(self: Field) void {
        // TODO: USING configs here might not be the best idea!
        const scale = configs.field_scale;
        const tile_size_u32 = self.spritesheet_ptr.getTileSize(scale);
        const tile_size: Vec2(f32) = @floatFromInt(tile_size_u32);
        const top_left = self.toRenderRect(scale).topLeft();

        for (0..self.grid.cols) |col| {
            for (0..self.grid.rows) |row| {
                const value = self.grid.get(col, row);
                const cell_pos: Vec2(f32) = .{ @floatFromInt(col), @floatFromInt(row) };

                const position: Vec2(f32) = top_left + tile_size * cell_pos;
                const position_aligned = position + tile_size * value.anchor;
                self.spritesheet_ptr.draw(
                    position_aligned,
                    scale,
                    value.anchor,
                    value.rotation.toDegrees(),
                    value.sprite_idx,
                    value.tint,
                );

                // debug draw colliders
                // if (self.collider_grid.get(col, row)) {
                //     rl.drawRectangleLinesEx(
                //         .{
                //             .x = position[0],
                //             .y = position[1],
                //             .width = tile_size[0],
                //             .height = tile_size[1],
                //         },
                //         2,
                //         rl.Color.green,
                //     );
                // } else {
                //     rl.drawRectangleLinesEx(
                //         .{
                //             .x = position[0],
                //             .y = position[1],
                //             .width = tile_size[0],
                //             .height = tile_size[1],
                //         },
                //         1,
                //         rl.Color.white,
                //     );
                // }
            }
        }
    }

    // ==================
    // === CONVERSION ===
    // ==================
    pub fn toRenderRect(self: Field, scale: Vec2(f32)) Rect {
        const grid_size: Vec2(u32) = .{ @intCast(self.grid.cols), @intCast(self.grid.rows) };
        const tile_size: Vec2(u32) = self.spritesheet_ptr.getTileSize(scale);
        const size_u32: Vec2(u32) = grid_size * tile_size;

        const pos_f32: Vec2(f32) = @floatFromInt(self.position);
        var size_offset_f32: Vec2(f32) = @floatFromInt(size_u32);
        size_offset_f32 *= self.origin;
        return .{
            .position = pos_f32 - size_offset_f32,
            .size = @floatFromInt(size_u32),
        };
    }

    pub fn toGridRect(self: Field) RectI {
        const size: Vec2(f32) = .{ @floatFromInt(self.grid.cols), @floatFromInt(self.grid.rows) };
        const pos_f32: Vec2(f32) = @floatFromInt(self.position);
        return .{
            .position = @intFromFloat(pos_f32 - size * self.origin),
            .size = @intFromFloat(size),
        };
    }
};

pub fn drawZeroLines(view_rec: Rect) void {
    rl.drawLineEx(
        .{ .x = 0, .y = view_rec.size[1] * -1 },
        .{ .x = 0, .y = view_rec.size[1] },
        2,
        .{ .r = 255, .g = 25, .b = 255, .a = 64 },
    );

    rl.drawLineEx(
        .{ .x = view_rec.size[0] * -1, .y = 0 },
        .{ .x = view_rec.size[0], .y = 0 },
        2,
        .{ .r = 255, .g = 25, .b = 255, .a = 64 },
    );
}

// ===========
// DRAW/RENDER
// ===========
pub fn drawVersion(font_ptr: *rl.Font, view_rec: Rect) !void {
    var bottom_right = view_rec.bottomRight();
    bottom_right[0] -= view_rec.size[0] * 0.05;
    bottom_right[1] -= view_rec.size[1] * 0.05;

    var buffer: [512]u8 = undefined;
    const buf = buffer[0..];
    const c_text = try std.fmt.bufPrintZ(buf, "{s}", .{configs.version});
    gui.common.drawText(
        c_text,
        bottom_right,
        .{
            .default = .{
                .font_ptr = font_ptr,
                .font_size = 15.0,
                .char_spacing = 4,
                .v_line_spacing = 2,
                .origin = .{ 1, 1 },
                .color = configs.TEXT_COLOR,
            },
        },
    );
}

pub fn drawFPS(view_rec: Rect) void {
    var fps_pos = view_rec.topRight();
    fps_pos[0] -= 100;
    fps_pos[1] = 25;
    rl.drawFPS(@intFromFloat(fps_pos[0]), @intFromFloat(fps_pos[1]));
}

// ===========
// VFX EFFECTS
// ===========

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

    pub fn update(self: *ScreenShakeVFX, cam_pos: *Vec2(f32)) void {
        if (self.frames == null) return;
        if (self.frames.? <= 0) {
            cam_pos.* = self.origin_position;
            self.frames = null;
            return;
        }

        const x: f32 = @floatFromInt(helpers.randomRangeI32(-3, 3));
        const y: f32 = @floatFromInt(helpers.randomRangeI32(-3, 3));
        const random_position: Vec2(f32) = .{
            self.origin_position[0] + x,
            self.origin_position[1] + y,
        };
        cam_pos.* = random_position;
        self.frames.? -= 1;
    }
};
