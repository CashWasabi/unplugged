const std = @import("std");
const rl = @import("raylib");

const Sprite = @import("Sprite.zig");
const SpriteSheet = @import("SpriteSheet.zig");
const ldtk = @import("ldtk.zig");
const SimplifiedLevelLoader = ldtk.SimplifiedLevelLoader;
const Level = ldtk.Level;

const Self = @This();

allocator: std.mem.Allocator,

fonts: std.StringHashMapUnmanaged(rl.Font) = .{},

// image -> Load image data into CPU memory (RAM)
// images: std.StringHashMapUnmanaged(rl.Image) = .{},

// texture Image converted to texture, GPU memory
textures: std.StringHashMapUnmanaged(rl.Texture2D) = .{},

// metadata on top of texture
sprites: std.StringHashMapUnmanaged(Sprite) = .{},
spritesheets: std.StringHashMapUnmanaged(SpriteSheet) = .{},

shaders: std.StringHashMapUnmanaged(rl.Shader) = .{},
sounds: std.StringHashMapUnmanaged(rl.Sound) = .{},

ldtk_data: std.StringHashMapUnmanaged(SimplifiedLevelLoader) = .{},
levels: std.StringHashMapUnmanaged(Level) = .{},

pub fn deinit(self: *Self) void {
    self.fonts.deinit(self.allocator);
    // self.images.deinit(self.allocator);
    self.textures.deinit(self.allocator);
    self.sprites.deinit(self.allocator);
    self.spritesheets.deinit(self.allocator);
    self.shaders.deinit(self.allocator);
    self.sounds.deinit(self.allocator);
    {
        var it = self.ldtk_data.valueIterator();
        while (it.next()) |v| v.deinit();
        self.ldtk_data.deinit(self.allocator);
    }
    {
        var it = self.levels.valueIterator();
        while (it.next()) |v| v.deinit();
        self.levels.deinit(self.allocator);
    }
}

pub fn loadFile(self: *Self, key: []const u8, filepath: [:0]const u8) !void {
    if (std.mem.endsWith(u8, filepath, ".ttf")) {
        const font = rl.loadFont(filepath);
        try self.fonts.put(self.allocator, key, font);
    } else if (std.mem.endsWith(u8, filepath, ".png")) {
        // const image = rl.loadImage(filepath);
        // try self.images.put(self.allocator, key, image);
        const texture = rl.loadTexture(filepath);
        try self.textures.put(self.allocator, key, texture);
    } else if (std.mem.endsWith(u8, filepath, ".ogg")) {
        const sound = rl.loadSound(filepath);
        try self.sounds.put(self.allocator, key, sound);
    }
}

const FolderType = enum {
    ldtk,
};
pub fn loadFolder(self: *Self, folder_type: FolderType, key: []const u8, folder: [:0]const u8) !void {
    switch (folder_type) {
        .ldtk => {
            const ldtk_data = try SimplifiedLevelLoader.fromFolder(self.allocator, folder);
            try self.ldtk_data.put(self.allocator, key, ldtk_data);
            const level = try Level.fromSimplifiedLevelLoader(self.allocator, &self.textures, ldtk_data);
            try self.levels.put(self.allocator, key, level);
        },
    }
}

test "asset_loader test" {
    return error.SkipZigTest;
}
