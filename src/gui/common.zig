const std = @import("std");
const rl = @import("raylib");
const vec2 = @import("../vec2.zig");
const Vec2 = vec2.Vec2;
const Rect = @import("../rect.zig").Rect;
const generics = @import("../generics.zig");

pub const TextGrid = generics.Grid([:0]const u8);

pub const ClickState = enum { out_of_bounds, hover, click, down, release };

pub fn checkLabelClick(bounds: Rect, point: Vec2(f32)) ClickState {
    var click_state: ClickState = .out_of_bounds;

    // zig fmt: off
    const in_bounds: bool = (
        bounds.position[0] <= point[0] and
        bounds.position[0] + bounds.size[0] >= point[0] and
        bounds.position[1] <= point[1] and
        bounds.position[1] + bounds.size[1] >= point[1]
    );
    // zig fmt: on

    if (!in_bounds) return click_state;

    click_state = .hover;

    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
        click_state = .click;
    } else if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
        click_state = .down;
    } else if (rl.isMouseButtonReleased(rl.MouseButton.mouse_button_left)) {
        click_state = .release;
    }

    return click_state;
}

pub const GridClickState = struct {
    position: Vec2(f32),
    click_state: ClickState,
};

pub fn checkGridClick(bounds: Rect, offset: Vec2(f32), opts: struct { debug: bool = false }) GridClickState {
    var click_state: ClickState = .out_of_bounds;
    var grid_position: Vec2(f32) = .{ -1, -1 };

    const mouse_pos: rl.Vector2 = rl.getMousePosition();

    // zig fmt: off
    const in_bounds: bool = (
        bounds.position[0] <= mouse_pos.x and
        bounds.position[0] + bounds.size[0] >= mouse_pos.x and
        bounds.position[1] <= mouse_pos.y and
        bounds.position[1] + bounds.size[1] >= mouse_pos.y
    );
    // zig fmt: on

    if (!in_bounds) {
        return .{
            .position = grid_position,
            .click_state = click_state,
        };
    }

    grid_position[0] = @divFloor(mouse_pos.x - bounds.position[0], offset[0]);
    grid_position[1] = @divFloor(mouse_pos.y - bounds.position[1], offset[1]);

    click_state = .hover;

    var color = rl.Color.yellow;
    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
        color = rl.Color.green;
        click_state = .click;
    } else if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
        color = rl.Color.orange;
        click_state = .down;
    } else if (rl.isMouseButtonReleased(rl.MouseButton.mouse_button_left)) {
        color = rl.Color.red;
        click_state = .release;
    }

    rl.drawRectangleLinesEx(.{
        .x = bounds.position[0] + offset[0] * grid_position[0],
        .y = bounds.position[1] + offset[1] * grid_position[1],
        .width = offset[0],
        .height = offset[1],
    }, 2, color);

    if (opts.debug) {
        const c = switch (click_state) {
            .click => rl.Color.green,
            .down => rl.Color.orange,
            .release => rl.Color.red,
            .hover => rl.Color.yellow,
            else => unreachable,
        };
        rl.drawRectangleLinesEx(
            .{
                .x = bounds.position[0] + offset[0] * grid_position[0],
                .y = bounds.position[1] + offset[1] * grid_position[1],
                .width = offset[0],
                .height = offset[1],
            },
            2,
            c,
        );
    }

    return .{
        .position = grid_position,
        .click_state = click_state,
    };
}

pub const AnchorOptions = struct {
    position: Vec2(f32) = .{ 0, 0 },
    anchor: Vec2(f32) = .{ 0, 0 },
};

pub const TextMode = union(enum) {
    default: struct {
        font_ptr: *rl.Font,
        char_spacing: f32 = 0,
        v_line_spacing: i32 = 1,
        font_size: f32 = 20.0,
        rotation: f32 = 0,
        color: rl.Color = rl.Color.white,
    },
    box: struct {
        // text based part
        font_ptr: *rl.Font,
        char_spacing: f32 = 0,
        v_line_spacing: i32 = 1,
        rotation: f32 = 0,
        color: rl.Color = rl.Color.white,

        // orientation part
        size: Vec2(f32),
        alignment: Vec2(f32) = .{ 0, 0 },
    },
};

pub fn getTextRect(text: [:0]const u8, text_mode: TextMode, anchor_opts: AnchorOptions) Rect {
    switch (text_mode) {
        .box => |tm| {
            return .{
                .position = anchor_opts.position - tm.size * anchor_opts.anchor,
                .size = tm.size,
            };
        },
        .default => |tm| {
            const measured: rl.Vector2 = rl.measureTextEx(
                tm.font_ptr.*,
                text,
                tm.font_size,
                tm.char_spacing,
            );
            const size: Vec2(f32) = .{ measured.x, measured.y };
            return .{
                .position = anchor_opts.position - size * anchor_opts.anchor,
                .size = size,
            };
        },
    }
}

pub fn drawText(text: [:0]const u8, text_mode: TextMode, anchor_opts: AnchorOptions) void {
    switch (text_mode) {
        .default => |tm| {
            rl.setTextLineSpacing(tm.v_line_spacing);
            const rotation: f32 = 0;
            const string_size: rl.Vector2 = rl.measureTextEx(
                tm.font_ptr.*,
                text,
                tm.font_size,
                tm.char_spacing,
            );
            rl.drawTextPro(
                tm.font_ptr.*,
                text,
                .{
                    .x = anchor_opts.position[0],
                    .y = anchor_opts.position[1],
                },
                .{
                    .x = string_size.x * anchor_opts.anchor[0],
                    .y = string_size.y * anchor_opts.anchor[1],
                },
                rotation,
                tm.font_size,
                tm.char_spacing,
                tm.color,
            );
        },
        .box => |tm| {
            const font = tm.font_ptr.*;
            rl.setTextLineSpacing(tm.v_line_spacing);
            const box_size = tm.size;
            const font_base_size: f32 = @floatFromInt(font.baseSize);
            const font_size = 15.0;

            // const text_length = text.len;
            const text_length: u32 = rl.textLength(text);
            const scale_factor: f32 = font_size / font_base_size;
            var text_offset_y: f32 = 0; // Offset between lines (on line break '\n')
            var text_offset_x: f32 = 0; // Offset X to next character to draw

            const max_text_length: i32 = 512;

            var i: i32 = 0;
            while (i < max_text_length) : (i += 1) {
                // Get next codepoint from byte string and glyph index in font
                var codepoint_byte_count: i32 = 0;

                const codepoint_byte: [1:0]u8 = [1:0]u8{text[@intCast(i)]};
                const c: [:0]const u8 = codepoint_byte[0..];
                const codepoint: u8 = @intCast(rl.getCodepoint(c, &codepoint_byte_count));

                // skip broken ones
                if (codepoint == 0x3f) codepoint_byte_count = 1;
                i += codepoint_byte_count - 1;

                const glyph_index: usize = @intCast(rl.getGlyphIndex(font, codepoint));
                var glyph_width: f32 = 0;
                if (codepoint != '\n') {
                    if (font.glyphs[glyph_index].advanceX == 0) {
                        glyph_width = font.recs[glyph_index].width * scale_factor;
                    } else {
                        glyph_width = @as(f32, @floatFromInt(font.glyphs[glyph_index].advanceX)) * scale_factor;
                    }
                    if (i + 1 < text_length) glyph_width = glyph_width + tm.char_spacing;
                }

                if (codepoint == '\n') { // linebreak
                    text_offset_y += (font_base_size + (font_base_size / 2)) * scale_factor;
                    text_offset_x = 0;
                } else {
                    if (text_offset_x + glyph_width > box_size[0]) { // wraparound box
                        text_offset_y += (font_base_size + font_base_size / 2) * scale_factor;
                        text_offset_x = 0;
                    }

                    // When text overflows rectangle height limit, just stop drawing
                    if (text_offset_y + font_base_size * scale_factor > box_size[1]) break;

                    // Draw current character glyph
                    if (codepoint != ' ' and codepoint != '\t') {
                        rl.drawTextCodepoint(
                            font,
                            codepoint,
                            .{
                                .x = anchor_opts.position[0] + text_offset_x,
                                .y = anchor_opts.position[1] + text_offset_y,
                            },
                            font_size,
                            tm.color,
                        );
                    }
                }

                // if end of line?
                if ((text_offset_x != 0) or codepoint != ' ') text_offset_x += glyph_width;
            }
        },
    }
}

pub fn drawTextGrid(text_grid: *TextGrid, bounds: Rect, text_mode: TextMode) void {
    const cols_f32: f32 = @floatFromInt(text_grid.cols);
    const rows_f32: f32 = @floatFromInt(text_grid.rows);
    const offset: Vec2(f32) = .{
        bounds.size[0] / cols_f32,
        bounds.size[1] / rows_f32,
    };

    switch (text_mode) {
        .default => |tm| {
            const origin: Vec2(f32) = offset * tm.origin;
            for (0..text_grid.cols) |col| {
                for (0..text_grid.rows) |row| {
                    const cell_pos: Vec2(f32) = .{
                        @floatFromInt(col),
                        @floatFromInt(row),
                    };
                    drawText(
                        text_grid.get(col, row),
                        .{bounds.position + offset * cell_pos + origin},
                        .{ .bounds = tm },
                    );
                }
            }
        },
        .bounds => |tm| {
            const origin: Vec2(f32) = offset * tm.origin;
            _ = origin;
        },
    }
}
