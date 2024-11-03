const std = @import("std");
const rl = @import("raylib");
const vec2 = @import("../vec2.zig");
const Vec2 = vec2.Vec2;
const Rect = @import("../rect.zig").Rect;
const common = @import("common.zig");
const TextMode = common.TextMode;
const AnchorOptions = common.AnchorOptions;

pub const Padding = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
};

pub const Margin = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
};

pub const DrawMode = union(enum) {
    empty,
    outline: struct {
        padding: Padding = .{},
        border: f32 = 1,
        margin: Padding = .{},
        color: rl.Color = rl.Color.white,
    },
    fill: struct {
        padding: Padding = .{},
        margin: Padding = .{},
        color: rl.Color = rl.Color.black,
    },
    filled_outline: struct {
        padding: Padding = .{},
        border: f32 = 1,
        margin: Padding = .{},
        fill_color: rl.Color = rl.Color.black,
        outline_color: rl.Color = rl.Color.black,
    },
};

pub fn getDrawRect(text_rect: Rect, draw_mode: DrawMode, anchor_opts: AnchorOptions) Rect {
    const bounds = text_rect;
    const position = anchor_opts.position;
    const anchor = anchor_opts.anchor;

    var top_left = bounds.topLeft();
    var bottom_right = bounds.bottomRight();

    switch (draw_mode) {
        .outline => |dm| {
            top_left = bounds.topLeft();
            top_left[0] -= dm.padding.left + dm.border;
            top_left[1] -= dm.padding.top + dm.border;

            bottom_right = bounds.bottomRight();
            bottom_right[0] += dm.padding.right + dm.border;
            bottom_right[1] += dm.padding.bottom + dm.border;
        },
        .filled_outline => |dm| {
            top_left = bounds.topLeft();
            top_left[0] -= dm.padding.left + dm.border;
            top_left[1] -= dm.padding.top + dm.border;

            bottom_right = bounds.bottomRight();
            bottom_right[0] += dm.padding.right + dm.border;
            bottom_right[1] += dm.padding.bottom + dm.border;
        },
        .fill => |dm| {
            top_left = bounds.topLeft();
            top_left[0] -= dm.padding.left;
            top_left[1] -= dm.padding.top;

            bottom_right = bounds.bottomRight();
            bottom_right[0] += dm.padding.right;
            bottom_right[1] += dm.padding.bottom;
        },
        .empty => {},
    }

    const size = bottom_right - top_left;
    return .{
        .position = position - size * anchor,
        .size = size,
    };
}

pub fn getAnchorOpts(draw_rect: Rect, draw_mode: DrawMode) AnchorOptions {
    var position = draw_rect.topLeft();
    switch (draw_mode) {
        .outline => |dm| {
            position[0] += dm.border + dm.padding.left;
            position[1] += dm.border + dm.padding.top;
        },
        .filled_outline => |dm| {
            position[0] += dm.border + dm.padding.left;
            position[1] += dm.border + dm.padding.top;
        },
        .fill => |dm| {
            position[0] += dm.padding.left;
            position[1] += dm.padding.top;
        },
        .empty => {},
    }

    return .{ .position = position, .anchor = .{ 0, 0 } };
}

pub fn label(
    text: [:0]const u8,
    text_mode: TextMode,
    draw_mode: DrawMode,
    anchor_opts: AnchorOptions,
) common.ClickState {
    const text_rect = common.getTextRect(text, text_mode, anchor_opts);
    const draw_rect = getDrawRect(text_rect, draw_mode, anchor_opts);

    const mouse_pos: rl.Vector2 = rl.getMousePosition();
    const rl_bounds: rl.Rectangle = .{
        .x = draw_rect.position[0],
        .y = draw_rect.position[1],
        .width = draw_rect.size[0],
        .height = draw_rect.size[1],
    };

    const click_state = common.checkLabelClick(draw_rect, .{ mouse_pos.x, mouse_pos.y });

    const color: ?rl.Color = switch (click_state) {
        .click => rl.Color.green,
        .down => rl.Color.orange,
        .release => rl.Color.red,
        .hover => rl.Color.yellow,
        .out_of_bounds => null,
    };

    // ============
    // DRAW OUTLINE
    // ============
    switch (draw_mode) {
        .outline => |dm| {
            rl.drawRectangleLinesEx(rl_bounds, dm.border, dm.color);
            if (color) |c| rl.drawRectangleLinesEx(rl_bounds, dm.border, c);
        },
        .fill => |dm| {
            rl.drawRectangleRec(rl_bounds, dm.color);
            if (color) |c| rl.drawRectangleRec(rl_bounds, c);
        },
        .filled_outline => |dm| {
            rl.drawRectangleRec(rl_bounds, dm.fill_color);
            if (color) |c| rl.drawRectangleRec(rl_bounds, c);

            rl.drawRectangleLinesEx(rl_bounds, dm.border, dm.outline_color);
            if (color) |c| rl.drawRectangleLinesEx(rl_bounds, dm.border, c);
        },
        .empty => {},
    }

    // =========
    // DRAW TEXT
    // =========
    const aligned_anchor_opts = getAnchorOpts(draw_rect, draw_mode);
    common.drawText(text, text_mode, aligned_anchor_opts);

    return click_state;
}

pub fn labelGrid(text_grid: *common.TextGrid, bounds: Rect, draw_mode: DrawMode, text_mode: common.TextMode) common.GridClickState {
    const cols_f32: f32 = @floatFromInt(text_grid.cols);
    const rows_f32: f32 = @floatFromInt(text_grid.rows);
    var offset_x: f32 = undefined;
    var offset_y: f32 = undefined;

    switch (draw_mode) {
        .outline => |dm| {
            // draw vertical lines
            offset_x = bounds.size[0] / cols_f32;
            for (0..text_grid.cols) |i| {
                const x = bounds.position[0] + offset_x * @as(f32, @floatFromInt(i));

                rl.drawLineV(
                    .{ .x = x, .y = bounds.position[1] },
                    .{ .x = x, .y = bounds.position[1] + bounds.size[1] },
                    dm.color,
                );
            }

            // draw horizontal lines
            offset_y = bounds.size[1] / rows_f32;
            for (0..text_grid.rows) |i| {
                const y = bounds.position[1] + offset_y * @as(f32, @floatFromInt(i));

                rl.drawLineV(
                    .{ .x = bounds.position[0], .y = y },
                    .{ .x = bounds.position[0] + bounds.size[0], .y = y },
                    dm.color,
                );
            }

            // draw bounds
            rl.drawRectangleLinesEx(
                .{
                    .x = bounds.position[0],
                    .y = bounds.position[1],
                    .width = bounds.size[0],
                    .height = bounds.size[1],
                },
                dm.border,
                dm.color,
            );
        },
        else => {},
    }

    common.drawTextGrid(text_grid, bounds, text_mode);
    return common.checkGridClick(bounds, .{ offset_x, offset_y }, .{});
}

pub fn drawFPS(target_fps: i32, text_mode: common.TextMode) !void {
    var buffer: [128]u8 = undefined;
    const buf = buffer[0..];
    const text = try std.fmt.bufPrintZ(
        buf,
        "TARGET FPS: {d}\nFPS: {d}",
        .{ target_fps, rl.getFPS() },
    );

    common.drawText(text, text_mode);
}
