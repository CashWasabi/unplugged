const rl = @import("raylib");
const helpers = @import("helpers.zig");
const Vec2 = @import("vec2.zig").Vec2;

pub const version = "0.1";
pub const title = "WFC";
pub const assets_folder = "assets";
pub const ldtk_folder = assets_folder ++ "/ldtk";
pub const fonts_folder = assets_folder ++ "/fonts";
pub const sprite_folder = assets_folder ++ "/sprite";
pub const sfx_folder = assets_folder ++ "/sfx";

pub const fps: f32 = 0;
pub const seed: u64 = 1337;

pub const max_piece_len = 15;

pub const tile_size: Vec2(u32) = .{ 16, 16 };
pub const tile_spacing: Vec2(u32) = .{ 1, 1 };
pub const resolution: Vec2(f32) = helpers.Resolution.itchIOp();
// pub const resolution: Vec2(f32) = helpers.Resolution.pc720p();
pub const field_scale: Vec2(f32) = .{ 1.8, 1.8 };
pub const field_grid: Vec2(usize) = .{ 17, 17 }; // keep it uneven for now!
pub const default_font: *rl.Font = undefined;

pub const BG_COLOR = rl.Color.black;
pub const TEXT_COLOR = rl.Color.white;
