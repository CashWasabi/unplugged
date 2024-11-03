const std = @import("std");
const rl = @import("raylib");

const Context = @import("../Context.zig");
const configs = @import("../configs.zig");

const gui = @import("../gui.zig");
const scene = @import("../scene.zig");
const vec2 = @import("../vec2.zig");
const Vec2 = vec2.Vec2;
const rect = @import("../rect.zig");
const Rect = rect.Rect;
const RectI = rect.RectI;
const SpriteSheet = @import("../SpriteSheet.zig");

const generics = @import("../generics.zig");
const Grid = generics.Grid;

const helpers = @import("../helpers.zig");
const vfx = @import("../vfx.zig");
const sfx = @import("../sfx.zig");

const Level = @import("../ldtk.zig").Level;

const world = @import("../world.zig");

pub const Input = struct {
    toggle_pull: bool = false,
    zoom_in: bool = false,
    zoom_out: bool = false,
    zoom_reset: bool = false,

    // ui
    ui_zoom_in: bool = false,
    ui_zoom_out: bool = false,
    ui_zoom_reset: bool = false,

    // next level
    ui_next_level: bool = false,

    // all plugged check
    all_plugged: bool = false,

    pub fn update(self: *Input) void {
        // pulling
        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
            self.toggle_pull = !self.toggle_pull;
        }

        // zoom
        self.zoom_in = rl.isKeyPressed(rl.KeyboardKey.key_i) or self.ui_zoom_in;
        self.zoom_out = rl.isKeyPressed(rl.KeyboardKey.key_o) or self.ui_zoom_out;
        self.zoom_reset = rl.isKeyPressed(rl.KeyboardKey.key_r) or self.ui_zoom_reset;
    }
};

pub const SceneData = struct {
    active_level: usize = 0,
    input: Input = .{},
    cursor: world.Cursor = .{},
    zoom_step: f32 = 0.1,
    screen_shake_vfx: vfx.ScreenShakeVFX = .{},
    window_size: Vec2(f32) = .{ 0, 0 },

    font_ptr: *rl.Font = undefined,
    theme_sfx: sfx.LoopEffect = undefined,
    level_ptr: *Level = undefined,
    field: world.Field = undefined,

    done: bool = false,

    pub fn deinit(self: *SceneData) void {
        self.field.deinit();
        self.theme_sfx.deinit();
    }
};

var SCENE_DATA: SceneData = .{};

pub fn load() scene.Scene {
    const vtable = scene.Scene.VTable{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
        .isFinished = isFinished,
    };

    return scene.init(&vtable);
}

fn init(ctx: *Context) !void {
    SCENE_DATA.window_size = ctx.window.size;
    ctx.cam.setViewport(ctx.window.size, .{ 0, 0 }, .{ 0.5, 0.5 });

    SCENE_DATA.font_ptr = ctx.assets.fonts.getPtr("berlin_bold.ttf").?;
    SCENE_DATA.theme_sfx = try sfx.LoopEffect.init(
        ctx.allocator,
        ctx.assets.sounds.getPtr("lobstercrew_puzzle.ogg").?,
        2,
    );
    _ = SCENE_DATA.theme_sfx.play();
    SCENE_DATA.done = false;

    // ================
    // LOAD FROM LEVEL
    // ================
    try loadLevel(ctx, "level_0");
}

fn loadLevel(ctx: *Context, level_name: []const u8) !void {
    // done if we dont have any more levels
    if (ctx.assets.levels.getPtr(level_name) == null) {
        SCENE_DATA.done = true;
        return;
    }

    SCENE_DATA.field.deinit();

    SCENE_DATA.input = .{};
    SCENE_DATA.cursor = .{};

    SCENE_DATA.level_ptr = ctx.assets.levels.getPtr(level_name).?;
    // prepare field grid
    const spritesheet_ptr = ctx.assets.spritesheets.getPtr("1_bit").?;
    SCENE_DATA.field = .{
        .position = .{ 0, 0 },
        .origin = .{ 0.5, 0.5 },
        .spritesheet_ptr = spritesheet_ptr,
        .grid = try world.TileGrid.init(ctx.allocator, configs.field_grid[0], configs.field_grid[1]),
        .collider_grid = try world.ColliderGrid.init(ctx.allocator, configs.field_grid[0], configs.field_grid[1]),
        .start_plug_list = world.TileList.init(ctx.allocator),
        .end_plug_list = world.TileList.init(ctx.allocator),
        .connector_list = world.TileList.init(ctx.allocator),
        .cutter_list = world.TileList.init(ctx.allocator),
        .pipe_line_list = world.PipeLineList.init(ctx.allocator),
    };
    const field_ptr = &SCENE_DATA.field;
    for (field_ptr.grid.cells) |*c| {
        c.* = .{ .sprite_idx = world.WorldSprite.toSpriteIdx(.unknown) };
    }
    if (SCENE_DATA.level_ptr.colliders) |collider_grid| {
        for (0..collider_grid.rows) |row| {
            for (0..collider_grid.cols) |col| {
                const value = collider_grid.get(col, row);
                _ = field_ptr.collider_grid.set(col, row, value == .collider);
            }
        }
    }

    // START PLUG
    if (SCENE_DATA.level_ptr.start_plugs) |start_plugs| {
        for (start_plugs.items) |start_plug| {
            try field_ptr.start_plug_list.append(.{
                .sprite_idx = world.WorldSprite.toSpriteIdx(.plug_on),
                .coords = start_plug.coords,
            });
            _ = field_ptr.grid.set(
                start_plug.coords[0],
                start_plug.coords[1],
                .{ .sprite_idx = world.WorldSprite.toSpriteIdx(.plug_on) },
            );
        }
    }

    // END PLUG
    if (SCENE_DATA.level_ptr.end_plugs) |end_plugs| {
        for (end_plugs.items) |end_plug| {
            try field_ptr.end_plug_list.append(.{
                .sprite_idx = world.WorldSprite.toSpriteIdx(.plug_off),
                .coords = end_plug.coords,
            });
            _ = field_ptr.grid.set(
                end_plug.coords[0],
                end_plug.coords[1],
                .{ .sprite_idx = world.WorldSprite.toSpriteIdx(.plug_off) },
            );
        }
    }

    // CONNECTOR
    if (SCENE_DATA.level_ptr.connectors) |connectors| {
        for (connectors.items) |connector| {
            try field_ptr.connector_list.append(.{
                .sprite_idx = world.WorldSprite.toSpriteIdx(.connector_off),
                .coords = connector.coords,
            });
            _ = field_ptr.grid.set(
                connector.coords[0],
                connector.coords[1],
                .{ .sprite_idx = world.WorldSprite.toSpriteIdx(.connector_off) },
            );
        }
    }

    // CUTTER
    if (SCENE_DATA.level_ptr.cutters) |cutters| {
        for (cutters.items) |cutter| {
            try field_ptr.cutter_list.append(.{
                .sprite_idx = world.WorldSprite.toSpriteIdx(.cutter),
                .coords = cutter.coords,
            });
            _ = field_ptr.grid.set(
                cutter.coords[0],
                cutter.coords[1],
                .{ .sprite_idx = world.WorldSprite.toSpriteIdx(.cutter) },
            );
        }
    }

    // for every start_plug/end_plug combination create a pipe_line
    for (field_ptr.start_plug_list.items) |start_plug| {
        for (field_ptr.end_plug_list.items) |end_plug| {
            try field_ptr.pipe_line_list.append(
                world.PipeLine.init(
                    ctx.allocator,
                    start_plug.coords,
                    end_plug.coords,
                    configs.max_piece_len,
                ),
            );
        }
    }
}

fn deinit(ctx: *Context) void {
    _ = ctx;
    SCENE_DATA.deinit();
}

fn draw(ctx: *Context) !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(configs.BG_COLOR);

    // const input_ptr = &SCENE_DATA.input;
    const field = SCENE_DATA.field;
    // const view_rec = ctx.cam.getViewport(ctx.window.size);

    // ---------------------------------------
    // WORLD DRAW
    // ---------------------------------------
    {
        ctx.cam.inner_cam.begin();
        defer ctx.cam.inner_cam.end();

        // world.drawZeroLines(view_rec);

        // draw layers
        for (SCENE_DATA.level_ptr.layers.items) |layer| {
            layer.draw(
                .{ 0, 0 },
                .{ configs.field_scale[0], configs.field_scale[1] },
                .{ 0.5, 0.5 },
                0,
                rl.Color.white,
            );
        }

        // draw field
        field.draw();
        // const cursor = SCENE_DATA.cursor;
        // cursor.draw(field, view_rec);
    }

    // ---------------------------------------
    // WINDOW DRAW
    // ---------------------------------------
    {
        const input_ptr = &SCENE_DATA.input;
        const window_rec = ctx.window.toRect();
        try drawPipeCounter(window_rec, SCENE_DATA.field.pipe_line_list.items[0]);
        if (input_ptr.all_plugged) {
            drawNextLevelButton(&SCENE_DATA.input, window_rec);
        }
    }
}

fn update(ctx: *Context) !void {
    const cursor_ptr = &SCENE_DATA.cursor;
    const field_ptr = &SCENE_DATA.field;
    const pipe_line_list_ptr = &field_ptr.pipe_line_list;
    const cutter_list_ptr = &field_ptr.cutter_list;
    const input_ptr = &SCENE_DATA.input;
    SCENE_DATA.theme_sfx.update();
    SCENE_DATA.screen_shake_vfx.update(&ctx.cam.inner_cam.target);
    input_ptr.update();

    if (input_ptr.zoom_out) {
        ctx.cam.zoomStep(-SCENE_DATA.zoom_step);
    } else if (input_ptr.zoom_in) {
        ctx.cam.zoomStep(SCENE_DATA.zoom_step);
    } else if (input_ptr.zoom_reset) {
        ctx.cam.setZoom(1.0);
    }

    if (rl.isWindowResized()) {
        ctx.window.resize();
        SCENE_DATA.window_size = ctx.window.size;
        ctx.cam.setViewport(
            ctx.window.size,
            .{ 0, 0 },
            .{ 0.5, 0.5 },
        );
    }

    const view_rec = ctx.cam.getViewport(ctx.window.size);

    // check win condition
    var all_plugged: bool = true;
    for (pipe_line_list_ptr.items) |pipe_line| {
        if (!pipe_line.isConnected()) {
            all_plugged = false;
        }
    }
    if (all_plugged) {
        if (!input_ptr.all_plugged) {
            SCENE_DATA.screen_shake_vfx.start(
                800,
                .{ ctx.cam.inner_cam.target.x, ctx.cam.inner_cam.target.y },
            );
        }
        input_ptr.all_plugged = all_plugged;
    }

    if (all_plugged) {
        if (input_ptr.ui_next_level) {
            if (SCENE_DATA.active_level < 6) {
                SCENE_DATA.active_level += 1;
            } else {
                SCENE_DATA.done = true;
            }
            var buffer: [512]u8 = undefined;
            const buf = buffer[0..];
            const text = try std.fmt.bufPrint(buf, "level_{d}", .{SCENE_DATA.active_level});
            try loadLevel(ctx, text);
        }

        return;
    }

    for (pipe_line_list_ptr.items) |*pipe_line_ptr| {
        for (cutter_list_ptr.items) |cutter| {
            for (pipe_line_ptr.pieces.items) |piece| {
                if (world.isNeighbour(@intCast(cutter.coords), @intCast(piece))) {
                    SCENE_DATA.screen_shake_vfx.start(
                        400,
                        .{ ctx.cam.inner_cam.target.x, ctx.cam.inner_cam.target.y },
                    );
                    input_ptr.toggle_pull = false;
                    break;
                }
            }
        }

        if (input_ptr.toggle_pull) {
            const maybe_coords = cursor_ptr.getFieldCoords(field_ptr.*, view_rec);
            if (maybe_coords) |coords| {
                // don't handle collider positions
                if (field_ptr.collider_grid.get(coords[0], coords[1])) break;

                if (!pipe_line_ptr.isPipePiece(coords) and
                    pipe_line_ptr.isTailNeighbour(coords))
                {
                    try pipe_line_ptr.addPiece(field_ptr, coords);
                }

                // TODO: get's call repeatedly when there's no piece available
                if (pipe_line_ptr.isPieceBeforeTailPiece(coords)) {
                    pipe_line_ptr.removeTailPiece(field_ptr);
                }
            }
        } else {
            if (!pipe_line_ptr.isConnected()) {
                pipe_line_ptr.removeAllPieces(field_ptr);
            }
        }
    }
}

fn isFinished() bool {
    return SCENE_DATA.done;
}

fn drawNextLevelButton(input_ptr: *Input, window_rec: Rect) void {
    const center = window_rec.center();
    const text =
        \\LEVEL COMPLETE!
        \\CONTINUE?
    ;

    const next_level = gui.basic.label(
        text,
        .{
            .default = .{
                .font_ptr = SCENE_DATA.font_ptr,
                .font_size = 20.0,
                .color = rl.Color.white,
            },
        },
        .{
            .filled_outline = .{
                .padding = .{ .top = 20, .right = 20, .bottom = 20, .left = 20 },
                .fill_color = rl.Color.black,
                .outline_color = rl.Color.white,
            },
        },
        .{
            .position = .{ center[0], center[1] },
            .anchor = .{ 0.5, 0.5 },
        },
    );

    input_ptr.ui_next_level = next_level == .click;
}

fn drawPipeCounter(window_rec: Rect, pipe_line: world.PipeLine) !void {
    var position: Vec2(f32) = window_rec.bottomRight();
    position -= Vec2(f32){ 10, 10 };
    var buffer: [56]u8 = undefined;
    const buf = buffer[0..];
    const c_text = try std.fmt.bufPrintZ(
        buf,
        "{d}/{d} PIPES",
        .{ pipe_line.pieces.items.len, pipe_line.max_piece_length },
    );

    _ = gui.basic.label(
        c_text,
        .{
            .default = .{
                .font_ptr = SCENE_DATA.font_ptr,
                .font_size = 20.0,
                .color = rl.Color.white,
            },
        },
        .{
            .filled_outline = .{
                .padding = .{ .top = 20, .right = 20, .bottom = 20, .left = 20 },
                .fill_color = rl.Color.black,
                .outline_color = rl.Color.white,
            },
        },
        .{
            .position = .{ position[0], position[1] },
            .anchor = .{ 1, 1 },
        },
    );
}
