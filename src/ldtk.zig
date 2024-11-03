const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");

const vec2 = @import("vec2.zig");
const Vec2 = vec2.Vec2;

const rect = @import("rect.zig");
const Rect = rect.Rect;
const RectI = rect.RectI;

const Sprite = @import("Sprite.zig");
const Grid = @import("generics.zig").Grid;
const Context = @import("Context.zig");
const AssetLoader = @import("AssetLoader.zig");

// ==========================
// Game Specific Data Types
// ==========================
pub const EntityType = enum {
    unmapped,
    start_plug,
    end_plug,
    connector,
    cutter,
};

pub const Entity = struct {
    enttiy_type: EntityType,
    coords: Vec2(u32),
};

pub const ColliderType = enum {
    unmapped,
    collider,
    trigger,

    pub fn fromLdtk(data: u8) ColliderType {
        return switch (data) {
            1 => .collider,
            2 => .trigger,
            else => .unmapped,
        };
    }
};

const EntityList = std.ArrayList(Entity);
const ColliderGrid = Grid(ColliderType);
const LayerList = std.ArrayList(Sprite);
pub const Level = struct {
    // level orientation
    rect: RectI,

    // level data
    start_plugs: ?EntityList,
    end_plugs: ?EntityList,
    connectors: ?EntityList,
    cutters: ?EntityList,
    colliders: ?ColliderGrid,
    layers: LayerList,

    pub fn deinit(self: *Level) void {
        if (self.start_plugs) |*start_plugs| start_plugs.deinit();
        if (self.end_plugs) |*end_plugs| end_plugs.deinit();
        if (self.connectors) |*connectors| connectors.deinit();
        if (self.colliders) |*colliders| colliders.deinit();
        self.layers.deinit();
    }

    pub fn fromSimplifiedLevelLoader(
        allocator: std.mem.Allocator,
        textures: *std.StringHashMapUnmanaged(rl.Texture2D),
        loader: SimplifiedLevelLoader,
    ) !Level {
        const level_rect: RectI = .{
            .position = .{ loader.x, loader.y },
            .size = .{ @intCast(loader.width), @intCast(loader.height) },
        };
        return .{
            .rect = level_rect,
            .start_plugs = try loadEntities(allocator, loader, "start_plug", .start_plug),
            .end_plugs = try loadEntities(allocator, loader, "end_plug", .end_plug),
            .connectors = try loadEntities(allocator, loader, "connector", .connector),
            .cutters = try loadEntities(allocator, loader, "cutter", .cutter),
            .colliders = try loadColliderGrid(allocator, loader),
            .layers = try loadLayers(allocator, textures, loader),
        };
    }
};

pub fn loadEntities(
    allocator: std.mem.Allocator,
    loader: SimplifiedLevelLoader,
    entity_name: []const u8,
    entity_type: EntityType,
) !?EntityList {
    var root = loader.parsed.value;
    const entities_value = root.object.get("entities").?;
    if (entities_value.object.get(entity_name)) |start_plugs| {
        var entities = EntityList.init(allocator);

        for (start_plugs.array.items) |start_plug| {
            const x = @divExact(
                @as(u32, @intCast(start_plug.object.get("x").?.integer)),
                @as(u32, @intCast(start_plug.object.get("width").?.integer)),
            );
            const y = @divExact(
                @as(u32, @intCast(start_plug.object.get("y").?.integer)),
                @as(u32, @intCast(start_plug.object.get("height").?.integer)),
            );
            try entities.append(.{
                .enttiy_type = entity_type,
                .coords = .{
                    x,
                    y,
                },
            });
        }
        return entities;
    }
    return null;
}

pub fn loadColliderGrid(allocator: std.mem.Allocator, loader: SimplifiedLevelLoader) !?ColliderGrid {
    var collider_grid = try ColliderGrid.init(
        allocator,
        loader.collider_int_grid.cols,
        loader.collider_int_grid.rows,
    );

    for (0..collider_grid.rows) |row| {
        for (0..collider_grid.cols) |col| {
            const data: u8 = @intCast(loader.collider_int_grid.get(col, row));
            _ = collider_grid.set(col, row, ColliderType.fromLdtk(data));
        }
    }

    return collider_grid;
}

// TODO: Do we really need context here?
pub fn loadLayers(
    allocator: std.mem.Allocator,
    textures: *std.StringHashMapUnmanaged(rl.Texture2D),
    loader: SimplifiedLevelLoader,
) !LayerList {
    var layers = LayerList.init(allocator);

    // create a list of layers and add sprites to assets
    for (loader.layer_paths) |path| {
        if (std.mem.startsWith(u8, std.fs.path.basename(path), "draw_")) {
            try textures.put(allocator, path, rl.loadTexture(path));
            const texture = textures.get(path).?;

            // TODO: do we need to fix position?
            try layers.append(.{ .texture = texture });
        }
    }

    return layers;
}

// =======================
// Generic Level Loading
// =======================
const IntGrid = Grid(u32);
pub const SimplifiedLevelLoader = struct {
    allocator: std.mem.Allocator,

    x: i32,
    y: i32,
    width: u32,
    height: u32,
    bg_color: []const u8,
    layer_paths: [][:0]const u8,
    collider_int_grid: IntGrid, // could be optional
    parsed: std.json.Parsed(std.json.Value),

    pub fn deinit(self: *SimplifiedLevelLoader) void {
        self.collider_int_grid.deinit();
        self.parsed.deinit();
        for (self.layer_paths) |path| self.allocator.free(path);
        self.allocator.free(self.layer_paths);
    }

    pub fn fromFolder(allocator: std.mem.Allocator, folder: []const u8) !SimplifiedLevelLoader {
        const data_json = blk: {
            const path = try std.fs.path.join(allocator, &.{ folder, "data.json" });
            defer allocator.free(path);

            const data = try readFile(allocator, path);
            break :blk data;
        };
        defer allocator.free(data_json);

        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, data_json, .{});

        var root = parsed.value;

        const x: i32 = @intCast(root.object.get("x").?.integer);
        const y: i32 = @intCast(root.object.get("y").?.integer);
        const width: u32 = @intCast(root.object.get("width").?.integer);
        const height: u32 = @intCast(root.object.get("height").?.integer);
        const bg_color: []const u8 = root.object.get("bgColor").?.string;

        const layer_items = root.object.get("layers").?.array.items;
        var layer_paths = std.ArrayList([:0]const u8).init(allocator);
        for (layer_items) |value| {
            const path = try std.fs.path.joinZ(
                allocator,
                &.{ folder, value.string },
            );
            try layer_paths.append(path);
        }

        const collider_int_grid = blk: {
            const path = try std.fs.path.join(allocator, &.{ folder, "colliders.csv" });
            defer allocator.free(path);
            const inner = try colliderIntGridFromFilePath(allocator, path);
            break :blk inner;
        };

        return .{
            .allocator = allocator,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .bg_color = bg_color,
            .layer_paths = try layer_paths.toOwnedSlice(),
            .collider_int_grid = collider_int_grid,
            .parsed = parsed,
        };
    }
};

pub fn colliderIntGridFromFilePath(allocator: std.mem.Allocator, file_path: []const u8) !IntGrid {
    const data: []u8 = try readFile(allocator, file_path);
    const data_trimmed = std.mem.trim(u8, data, "\n");
    defer allocator.free(data);

    var row_it = std.mem.split(u8, data_trimmed, "\n");
    const first_row = row_it.peek().?;
    const width: u32 = @intCast(std.mem.count(u8, first_row, ","));

    var row_list = std.ArrayList([]const u8).init(allocator);
    defer row_list.deinit();
    while (row_it.next()) |row| {
        try row_list.append(row);
    }
    const height: u32 = @intCast(row_list.items.len);

    var int_grid = try IntGrid.init(allocator, width, height);
    for (0..int_grid.rows) |row| {
        const row_string = row_list.items[row];
        const row_string_trimmed = std.mem.trim(u8, row_string, ",");
        var col: usize = 0;

        var col_string_it = std.mem.split(u8, row_string_trimmed, ",");
        while (col_string_it.next()) |col_string| {
            const num = try std.fmt.parseInt(u32, col_string, 10);
            _ = int_grid.set(col, row, num);
            col += 1;
        }
    }

    return int_grid;
}

pub fn readFile(allocator: std.mem.Allocator, filePath: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();

    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();

    const file_size: usize = @intCast((try file.stat()).size);
    try stream.readAllArrayList(&data, file_size);

    std.debug.assert(data.items.len > 0);

    return try data.toOwnedSlice();
}

// pub fn pathJoin(allocator: std.mem.Allocator, paths: []const []const u8) ![]u8 {
//     var path: []u8 = undefined;
//
//     switch (builtin.os.tag) {
//         // .emscripten => {
//         //     path = "";
//         // },
//         else => {
//             path = try std.fs.path.join(allocator, paths);
//         },
//     }
//
//     return path;
// }

test "test read file" {}
test "test path join" {}

test "test simplified level loader" {
    const path = "assets/ldtk/wfc/level_0.ldtkl";
    var loader = try SimplifiedLevelLoader.fromFile(std.testing.allocator, path);
    defer loader.deinit();
}

test "test level" {
    const path = "assets/ldtk/wfc/level_0.ldtkl";
    var loader = try SimplifiedLevelLoader.fromFile(std.testing.allocator, path);
    defer loader.deinit();

    // TODO: ctx is missing
    var level = Level.fromSimplifiedLevelLoader(std.testing.allocator, loader);
    defer level.deinit();
}
