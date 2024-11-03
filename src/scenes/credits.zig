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
const sfx = @import("../sfx.zig");

pub const Input = struct {
    // ctl
    any_button: bool = false,

    pub fn update(self: *Input) void {
        self.any_button = (rl.isKeyPressed(rl.KeyboardKey.key_space) or
            rl.isKeyPressed(rl.KeyboardKey.key_enter) or
            rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left) or
            rl.isMouseButtonPressed(rl.MouseButton.mouse_button_right) or
            rl.isGestureDetected(rl.Gesture.gesture_tap));
    }
};

pub const SceneData = struct {
    input: Input = .{},
    font_ptr: *rl.Font = undefined,
    window_size: Vec2(f32) = .{ 0, 0 },
    done: bool = false,
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
    SCENE_DATA.done = false;
}

fn deinit(ctx: *Context) void {
    _ = ctx;
}

fn draw(ctx: *Context) !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(configs.BG_COLOR);

    // const view_rec = ctx.cam.getViewport(ctx.window.size);
    // ---------------------------------------
    // WORLD DRAW
    // ---------------------------------------
    {
        ctx.cam.inner_cam.begin();
        defer ctx.cam.inner_cam.end();
    }

    // ---------------------------------------
    // WINDOW DRAW
    // ---------------------------------------
    {
        const window_rec = ctx.window.toRect();
        drawUI(window_rec);
    }
}

fn update(ctx: *Context) !void {
    var input_ptr = &SCENE_DATA.input;
    input_ptr.update();

    if (rl.isWindowResized()) {
        ctx.window.resize();
        SCENE_DATA.window_size = ctx.window.size;
        ctx.cam.setViewport(
            ctx.window.size,
            .{ 0, 0 },
            .{ 0.5, 0.5 },
        );
    }

    if (input_ptr.any_button) {
        // reload menu
        // SCENE_DATA.done = true;
    }
}

fn isFinished() bool {
    return SCENE_DATA.done;
}

fn drawUI(window_rec: Rect) void {
    const position = window_rec.center();
    gui.common.drawText(
        "Thank you for playing!",
        .{
            .default = .{
                .font_ptr = SCENE_DATA.font_ptr,
                .font_size = 50.0,
                .color = rl.Color.white,
            },
        },
        .{
            .position = position + Vec2(f32){ 0, -100 },
            .anchor = .{ 0.5, 0.5 },
        },
    );

    gui.common.drawText(
        \\Programming: LemonDiscoTech.
        \\
        \\Music: LobsterCrew
        \\
        \\Assets: KenneyNL
    ,
        .{
            .default = .{
                .font_ptr = SCENE_DATA.font_ptr,
                .font_size = 30.0,
                .color = rl.Color.white,
            },
        },
        .{
            .position = position + Vec2(f32){ 0, 50 },
            .anchor = .{ 0.5, 0.5 },
        },
    );
}
