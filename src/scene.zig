// inspired by:
// https://codeberg.org/gnarz/zig-raylib-template/src/branch/main/src/screen.zig
const Context = @import("Context.zig");

pub const Scene = struct {
    pub const VTable = struct {
        init: *const fn (ctx: *Context) anyerror!void,
        deinit: *const fn (ctx: *Context) void,
        draw: *const fn (ctx: *Context) anyerror!void,
        update: *const fn (ctx: *Context) anyerror!void,
        isFinished: *const fn () bool,
        getValue: *const fn () i32 = defaultGetValue,
    };

    vtable: *const VTable,

    pub fn defaultGetValue() i32 {
        return 0;
    }

    pub fn init(self: Scene, ctx: *Context) !void {
        return try self.vtable.init(ctx);
    }

    pub fn deinit(self: *Scene, ctx: *Context) void {
        return self.vtable.deinit(ctx);
    }

    pub fn draw(self: *Scene, ctx: *Context) !void {
        return try self.vtable.draw(ctx);
    }

    pub fn update(self: *Scene, ctx: *Context) !void {
        return try self.vtable.update(ctx);
    }

    pub fn isFinished(self: *Scene) bool {
        return self.vtable.isFinished();
    }

    pub fn getValue(self: *Scene) i32 {
        return self.vtable.getValue();
    }
};

pub fn init(vtable: *const Scene.VTable) Scene {
    return .{
        .vtable = vtable,
    };
}

test "asset_loader test" {
    return error.SkipZigTest;
}
