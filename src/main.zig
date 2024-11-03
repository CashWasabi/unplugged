const std = @import("std");
const rl = @import("raylib");
const emscripten = std.os.emscripten;
const builtin = @import("builtin");

const Context = @import("Context.zig");
const helpers = @import("helpers.zig");

const SceneSystem = @import("SceneSystem.zig");
const SpriteSheet = @import("SpriteSheet.zig");
const scenes = @import("scenes.zig");
const configs = @import("configs.zig");

export fn resizeWeb(width: i32, height: i32) void {
    rl.setWindowSize(width, height);
}

pub fn loadRessources(ctx: *Context) !void {
    //==============
    // FONT DEFAULT
    //==============
    try ctx.assets.fonts.put(ctx.allocator, "default", rl.getFontDefault());
    try ctx.assets.loadFile("berlin_regular.ttf", configs.fonts_folder ++ "/berlin_regular.ttf");
    try ctx.assets.loadFile("berlin_bold.ttf", configs.fonts_folder ++ "/berlin_bold.ttf");

    //===================
    // PIPES SPRITESHEET
    //===================
    try ctx.assets.loadFile("1_bit.png", configs.sprite_folder ++ "/1_bit.png");
    try ctx.assets.spritesheets.put(
        ctx.allocator,
        "1_bit",
        SpriteSheet.fromTileSize(
            ctx.assets.textures.get("1_bit.png").?,
            configs.tile_size,
            .{ 0, 0 },
        ),
    );

    //=====
    // SFX
    //=====
    try ctx.assets.loadFile("lobstercrew_puzzle.ogg", configs.sfx_folder ++ "/lobstercrew_puzzle.ogg");

    //========
    // Levels
    //========
    try ctx.assets.loadFolder(.ldtk, "level_0", configs.ldtk_folder ++ "/wfc/simplified/level_0");
    try ctx.assets.loadFolder(.ldtk, "level_1", configs.ldtk_folder ++ "/wfc/simplified/level_1");
    try ctx.assets.loadFolder(.ldtk, "level_2", configs.ldtk_folder ++ "/wfc/simplified/level_2");
    try ctx.assets.loadFolder(.ldtk, "level_3", configs.ldtk_folder ++ "/wfc/simplified/level_3");
    try ctx.assets.loadFolder(.ldtk, "level_4", configs.ldtk_folder ++ "/wfc/simplified/level_4");
}

pub fn updateDrawFrameNative(ctx: *Context) void {
    ctx.scene_system.update(ctx) catch |err| {
        std.log.debug("Failed to update scene!", .{});
        std.log.debug("Error: {}", .{err});
    };
    ctx.scene_system.draw(ctx) catch |err| {
        std.log.debug("Failed to draw scene!", .{});
        std.log.debug("Error: {}", .{err});
    };
}

pub fn updateDrawFrameWeb(arg: ?*anyopaque) callconv(.C) void {
    const ctx: *Context = @ptrCast(@alignCast(arg));
    updateDrawFrameNative(ctx);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // TODO: also set window MIN/MAX size!
    const resolution = switch (builtin.os.tag) {
        .emscripten => configs.resolution,
        else => configs.resolution,
    };

    const allocator = switch (builtin.os.tag) {
        .emscripten => std.heap.c_allocator,
        else => gpa.allocator(),
    };

    var ctx = try Context.init(allocator, resolution, configs.fps);
    defer ctx.deinit();

    // TODO: setup sound somewhere else maybe?
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    // load resources
    std.log.debug("Loading Resources ...", .{});
    try loadRessources(&ctx);
    std.log.debug("Loading resources done ...", .{});

    // setup scenes
    std.log.debug("Setting Up Scenes in call order...", .{});

    _ = try ctx.scene_system.add(&ctx, scenes.menu.load());
    _ = try ctx.scene_system.add(&ctx, scenes.level.load());
    _ = try ctx.scene_system.add(&ctx, scenes.credits.load());

    std.log.debug("Setting up initial scene  ...", .{});
    try ctx.scene_system.goto(&ctx, 0);

    std.log.debug("Scene setup done ...", .{});

    switch (builtin.os.tag) {
        .emscripten => {
            emscripten.emscripten_set_main_loop_arg(&updateDrawFrameWeb, &ctx, ctx.window.target_fps, 1);
        },
        else => {
            rl.setTargetFPS(configs.fps);
            while (!rl.windowShouldClose()) updateDrawFrameNative(&ctx);
        },
    }
}
