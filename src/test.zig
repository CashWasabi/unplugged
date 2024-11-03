const std = @import("std");

test "test main" {
    const ldtk = @import("ldtk.zig");
    _ = ldtk;

    std.testing.refAllDecls(@This());
}
