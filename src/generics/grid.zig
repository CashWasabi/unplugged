const std = @import("std");

// TODO: add option for: row major or column major
pub fn Grid(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        cols: usize,
        rows: usize,
        cells: []T,

        pub fn init(allocator: std.mem.Allocator, cols: usize, rows: usize) !Self {
            const cells = try allocator.alloc(T, cols * rows);
            return .{ .allocator = allocator, .cols = cols, .rows = rows, .cells = cells };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.cells);
        }

        pub fn fromSlice(allocator: std.mem.Allocator, cols: usize, rows: usize, array: []T) !Self {
            std.debug.assert(array.len == cols * rows);
            const cells = try allocator.alloc(T, cols * rows);
            for (0..cells.len) |i| cells[i] = array[i];
            return .{ .allocator = allocator, .cols = cols, .rows = rows, .cells = cells };
        }

        pub fn inBounds(self: Self, col: usize, row: usize) bool {
            if (col >= self.cols or row >= self.rows) {
                return false;
            } else {
                return true;
            }
        }

        // pub fn format(value: ?, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            return writer.print(
                "Grid{{.cols={d}, .rows={d}, .cells_len={d} }}",
                .{ self.cols, self.rows, self.cells.len },
            );
        }

        pub fn getIdx(self: Self, col: usize, row: usize) usize {
            std.debug.assert(row < self.rows);
            std.debug.assert(col < self.cols);
            return if (self.rows < self.cols) self.rows * row + col else self.cols * col + row;
        }

        pub fn get(self: Self, col: usize, row: usize) T {
            return self.cells[self.getIdx(col, row)];
        }

        pub fn getPtr(self: Self, col: usize, row: usize) *T {
            return &self.cells[self.getIdx(col, row)];
        }

        pub fn set(self: *Self, col: usize, row: usize, val: T) usize {
            const idx = self.getIdx(col, row);
            self.cells[idx] = val;
            return idx;
        }

        // TODO: we might need to do the same as the above functions here!
        // pub fn getColRow(self: *Self, idx: usize) struct { usize, usize } {
        //     const row = @divFloor(idx, self.rows);
        //     const col = idx - self.rows * row;
        //     return .{ col, row };
        // }
    };
}

pub fn BoundedGrid(comptime T: type, cols: usize, rows: usize) type {
    return struct {
        const Self = @This();
        const capacity = cols * rows;

        cols: usize = cols,
        rows: usize = rows,
        cells: std.BoundedArray(T, capacity) = .{},

        pub fn inBounds(self: Self, col: usize, row: usize) bool {
            if (col >= self.cols or row >= self.rows) {
                return false;
            } else {
                return true;
            }
        }

        // pub fn format(value: ?, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            return writer.print(
                "Grid{{.cols={d}, .rows={d}, .cells_len={d} }}",
                .{ self.cols, self.rows, self.cells.slice().len },
            );
        }

        pub fn getIdx(self: Self, col: usize, row: usize) usize {
            std.debug.assert(row < self.rows);
            std.debug.assert(col < self.cols);
            return if (self.rows < self.cols) self.rows * row + col else self.cols * col + row;
        }

        pub fn get(self: Self, col: usize, row: usize) T {
            return self.cells.get(self.getIdx(col, row));
        }

        pub fn getPtr(self: Self, col: usize, row: usize) *T {
            return &self.cells.slice()[self.getIdx(col, row)];
        }

        pub fn set(self: *Self, col: usize, row: usize, val: T) usize {
            const idx = self.getIdx(col, row);
            self.cells.set(idx, val);
            return idx;
        }
    };
}
