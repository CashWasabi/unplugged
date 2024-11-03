const std = @import("std");
const rl = @import("raylib");

const Cam = @import("../Cam.zig");
const Context = @import("../Context.zig");

const configs = @import("../configs.zig");
const gui = @import("../gui.zig");
const scene = @import("../scene.zig");
const game = @import("../game.zig");

const Vec2 = @import("../vec2.zig").Vec2;

pub const Input = struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,

    move_offset: bool = false,

    focus: bool = false,

    zoom_in: bool = false,
    zoom_out: bool = false,

    pub fn update(self: *Input) void {
        self.left = rl.isKeyPressed(rl.KeyboardKey.key_h) or rl.isKeyPressed(rl.KeyboardKey.key_a);
        self.down = rl.isKeyPressed(rl.KeyboardKey.key_j) or rl.isKeyPressed(rl.KeyboardKey.key_s);
        self.up = rl.isKeyPressed(rl.KeyboardKey.key_k) or rl.isKeyPressed(rl.KeyboardKey.key_w);
        self.right = rl.isKeyPressed(rl.KeyboardKey.key_l) or rl.isKeyPressed(rl.KeyboardKey.key_d);

        self.move_offset = rl.isKeyDown(rl.KeyboardKey.key_left_shift);

        self.zoom_in = rl.isKeyPressed(rl.KeyboardKey.key_i);
        self.zoom_out = rl.isKeyPressed(rl.KeyboardKey.key_o);

        self.focus = rl.isKeyPressed(rl.KeyboardKey.key_f);
    }
};

pub const SceneData = struct {
    // defaults
    input: Input = .{},
    font_ptr: *rl.Font = undefined,
    window_size: Vec2(f32) = .{ 0, 0 },
    done: bool = false,

    // extras
    move_step: f32 = 100,
    zoom_step: f32 = 0.1,

    screen_shake_vfx: game.ScreenShakeVFX = .{},

    pub fn deinit(self: *SceneData) void {
        _ = self;
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

    SCENE_DATA.font_ptr = ctx.assets.fonts.getPtr("astro_space.ttf").?;
    SCENE_DATA.done = false;
}

fn deinit(ctx: *Context) void {
    _ = ctx;
    SCENE_DATA.deinit();
}

fn draw(ctx: *Context) !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.white);

    // const view_rec = ctx.cam.toViewportRect(ctx.window.size);

    // ---------------------------------------
    // WORLD DRAW
    // ---------------------------------------
    {
        ctx.cam.begin();
        defer ctx.cam.end();

        drawCross(.{ 0, 0 }, 3000, 10, rl.Color.black); // draw cross at 0,0

        // draw target
        const cam_target: Vec2(f32) = .{ ctx.cam.inner_cam.target.x, ctx.cam.inner_cam.target.y };
        drawCross(cam_target, 100, 100, rl.Color.green); // draw cross at cam target

        // draw offset
        const cam_offset: Vec2(f32) = .{
            ctx.cam.inner_cam.target.x - ctx.cam.inner_cam.offset.x,
            ctx.cam.inner_cam.target.y - ctx.cam.inner_cam.offset.y,
        };
        drawCross(cam_offset, 50, 50, rl.Color.red); // draw cross at cam target

        const size = 500;
        rl.drawRectangleLinesEx(
            .{
                .x = -size * 0.5,
                .y = -size * 0.5,
                .width = size,
                .height = size,
            },
            10,
            rl.Color.blue,
        );
    }

    // ---------------------------------------
    // WINDOW DRAW
    // ---------------------------------------
    {
        const window_rec = ctx.window.toRect();
        game.drawFPS(window_rec);
        const center = window_rec.center();

        drawCross(center, 100, 2, rl.Color.blue);

        const text: [:0]const u8 = "CENTER";
        const font_ptr: *rl.Font = SCENE_DATA.font_ptr;
        const font_size: f32 = 20;

        // font has char spacing in itself
        const char_spacing: f32 = 0;
        _ = gui.basic.label(
            text,
            .{
                .default = .{
                    .font_ptr = font_ptr,
                    .font_size = font_size,
                    .char_spacing = char_spacing,
                    .color = rl.Color.black,
                },
            },
            .empty,
            .{
                .position = center,
                .anchor = .{ 0.5, 0.5 },
            },
        );

        const bottom_center = window_rec.bottomCenter();

        const cam_info_pos = bottom_center + bottom_center * Vec2(f32){ 0.5, 0 };
        try drawCamInfo(&ctx.cam, cam_info_pos);

        // const box_pos = bottom_center - bottom_center * Vec2(f32){ 0.5, 0 };
        // try drawTextBox(box_pos);
    }
}

fn update(ctx: *Context) !void {
    var input_ptr = &SCENE_DATA.input;
    input_ptr.update();

    if (input_ptr.move_offset) {
        if (input_ptr.left) {
            ctx.cam.inner_cam.offset.x += SCENE_DATA.move_step;
        } else if (input_ptr.down) {
            ctx.cam.inner_cam.offset.y -= SCENE_DATA.move_step;
        } else if (input_ptr.up) {
            ctx.cam.inner_cam.offset.y += SCENE_DATA.move_step;
        } else if (input_ptr.right) {
            ctx.cam.inner_cam.offset.x -= SCENE_DATA.move_step;
        }
    } else {
        if (input_ptr.left) {
            ctx.cam.inner_cam.target.x -= SCENE_DATA.move_step;
        } else if (input_ptr.down) {
            ctx.cam.inner_cam.target.y += SCENE_DATA.move_step;
        } else if (input_ptr.up) {
            ctx.cam.inner_cam.target.y -= SCENE_DATA.move_step;
        } else if (input_ptr.right) {
            ctx.cam.inner_cam.target.x += SCENE_DATA.move_step;
        }
    }

    if (input_ptr.zoom_out) {
        ctx.cam.zoomStep(-SCENE_DATA.zoom_step);
    } else if (input_ptr.zoom_in) {
        ctx.cam.zoomStep(SCENE_DATA.zoom_step);
    }

    if (input_ptr.focus) {
        const size: f32 = 500;
        ctx.cam.scaleToViewport(.{
            .position = .{ -size * 0.5, -size * 0.5 },
            .size = .{ size, size },
        }, .{});
    }

    if (rl.isWindowResized()) {
        ctx.window.resize();
        SCENE_DATA.window_size = ctx.window.size;
        ctx.cam.setViewport(ctx.window.size, .{ 0, 0 }, .{ 0.5, 0.5 });
    }
}

fn isFinished() bool {
    return SCENE_DATA.done;
}

// ========================
// SCENE SCOPE FUNCTIONS
// ========================
pub fn drawCross(position: Vec2(f32), length_half: f32, thickness: f32, color: rl.Color) void {
    rl.drawLineEx(
        .{ .x = position[0], .y = position[1] - length_half },
        .{ .x = position[0], .y = position[1] + length_half },
        thickness,
        color,
    );

    rl.drawLineEx(
        .{ .x = position[0] - length_half, .y = position[1] },
        .{ .x = position[0] + length_half, .y = position[1] },
        thickness,
        color,
    );
}

pub fn drawTextBox(position: Vec2(f32)) !void {
    const text: [:0]const u8 =
        \\ Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        \\ Vestibulum venenatis tincidunt lectus, nec sollicitudin erat pharetra ut.
        \\ Vivamus dapibus facilisis augue in dictum.
        \\ Sed fermentum nulla ut orci sagittis vestibulum.
        \\ In ac ligula vitae lacus aliquam vehicula.
        \\ Suspendisse nec orci elementum, sagittis nibh id, semper neque.
        \\ Sed semper nunc eu suscipit pellentesque.
        \\ Vestibulum vel velit dui.
        \\ Suspendisse imperdiet turpis sem, id finibus tortor pharetra ut.
        \\ Nullam venenatis tellus a felis luctus fermentum.
        \\ Etiam a velit sit amet lorem condimentum viverra pretium vitae neque.
        \\ Sed lobortis consequat metus."
    ;
    _ = gui.basic.label(
        text,
        .{
            .box = .{
                .font_ptr = SCENE_DATA.font_ptr,
                .char_spacing = 0,
                .color = rl.Color.black,
                .size = .{ 300, 300 },
            },
        },
        .{
            .filled_outline = .{
                .padding = .{ .left = 10, .right = 10, .top = 5, .bottom = 5 },
                .border = 10,
                .fill_color = .{ .r = 0, .g = 0, .b = 0, .a = 100 },
                .outline_color = rl.Color.orange,
            },
        },
        .{
            .position = position,
            .anchor = .{ 0.5, 1 },
        },
    );
}

pub fn drawCamInfo(cam: *Cam, position: Vec2(f32)) !void {
    const text =
        \\ Default Text
        \\ ======================================
        \\ Target:  {d}|{d}
        \\ Offset:  {d}|{d}
        \\ PADDING: {d}|{d}|{d}|{d}
        \\ ======================================
    ;

    var buffer: [512]u8 = undefined;
    const buf = buffer[0..];
    const c_text = try std.fmt.bufPrintZ(
        buf,
        text,
        .{
            cam.inner_cam.target.x,
            cam.inner_cam.target.y,
            cam.inner_cam.offset.x,
            cam.inner_cam.offset.y,
            cam.padding.top,
            cam.padding.right,
            cam.padding.bottom,
            cam.padding.left,
        },
    );

    _ = gui.basic.label(
        c_text,
        .{
            .default = .{
                .font_ptr = SCENE_DATA.font_ptr,
                .font_size = 20.0,
                .color = rl.Color.black,
            },
        },
        .{
            .filled_outline = .{
                .padding = .{ .left = 10, .right = 10, .top = 5, .bottom = 5 },
                .border = 10,
                .fill_color = .{ .r = 0, .g = 0, .b = 0, .a = 100 },
                .outline_color = rl.Color.orange,
            },
        },
        .{
            .position = position,
            .anchor = .{ 0.5, 1 },
        },
    );
}
