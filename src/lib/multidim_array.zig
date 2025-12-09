const std = @import("std");

/// A generic multi-dimensional array stored as a contiguous block of memory.
/// Uses row-major ordering for index calculation.
///
/// Example usage:
///   var arr = try MultiDimArray(i32).init(allocator, &[_]usize{3, 4, 5});
///   defer arr.deinit();
///   arr.set(&[_]usize{1, 2, 3}, 42);
///   const value = arr.get(&[_]usize{1, 2, 3});
pub fn MultiDimArray(comptime T: type) type {
    return struct {
        const Self = @This();
        data: []T,
        dims: []usize,
        strides: []usize,
        allocator: std.mem.Allocator,

        /// Initialize a new multi-dimensional array with the given dimensions.
        /// All elements are initialized to undefined.
        pub fn init(allocator: std.mem.Allocator, dimensions: []const usize) !Self {
            if (dimensions.len == 0) {
                return error.InvalidDimensions;
            }

            // Calculate total size
            var total_size: usize = 1;
            for (dimensions) |dim| {
                if (dim == 0) {
                    return error.InvalidDimensions;
                }
                total_size *= dim;
            }

            const data = try allocator.alloc(T, total_size);
            const dims = try allocator.dupe(usize, dimensions);
            const strides = try allocator.alloc(usize, dimensions.len);

            // Calculate strides for each dimension (row-major ordering)
            var stride: usize = 1;
            var i = dimensions.len;
            while (i > 0) {
                i -= 1;
                strides[i] = stride;
                stride *= dimensions[i];
            }

            return Self{
                .data = data,
                .dims = dims,
                .strides = strides,
                .allocator = allocator,
            };
        }

        /// Free all allocated memory.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
            self.allocator.free(self.dims);
            self.allocator.free(self.strides);
        }

        /// Calculate the flat index from multi-dimensional indices.
        fn calculateIndex(self: Self, indices: []const usize) usize {
            std.debug.assert(indices.len == self.dims.len);

            var index: usize = 0;
            for (indices, 0..) |idx, i| {
                std.debug.assert(idx < self.dims[i]);
                index += idx * self.strides[i];
            }
            return index;
        }

        /// Get the value at the specified indices.
        pub fn get(self: Self, indices: []const usize) T {
            return self.data[self.calculateIndex(indices)];
        }

        /// Set the value at the specified indices.
        pub fn set(self: *Self, indices: []const usize, value: T) void {
            self.data[self.calculateIndex(indices)] = value;
        }

        /// Get a pointer to the value at the specified indices.
        pub fn getPtr(self: *Self, indices: []const usize) *T {
            return &self.data[self.calculateIndex(indices)];
        }

        /// Get the value at the specified indices using a tuple/struct.
        /// Allows convenient syntax like: arr.getAt(.{1, 2, 3})
        pub fn getAt(self: Self, indices: anytype) T {
            const indices_array = tupleToArray(indices);
            return self.get(&indices_array);
        }

        /// Set the value at the specified indices using a tuple/struct.
        /// Allows convenient syntax like: arr.setAt(.{1, 2, 3}, value)
        pub fn setAt(self: *Self, indices: anytype, value: T) void {
            const indices_array = tupleToArray(indices);
            self.set(&indices_array, value);
        }

        /// Get a pointer to the value at the specified indices using a tuple/struct.
        pub fn getPtrAt(self: *Self, indices: anytype) *T {
            const indices_array = tupleToArray(indices);
            return self.getPtr(&indices_array);
        }

        /// Convert a tuple/struct to an array of indices.
        fn tupleToArray(indices: anytype) [std.meta.fields(@TypeOf(indices)).len]usize {
            const fields = std.meta.fields(@TypeOf(indices));
            var result: [fields.len]usize = undefined;
            inline for (fields, 0..) |field, i| {
                result[i] = @field(indices, field.name);
            }
            return result;
        }

        /// Fill the entire array with a single value.
        pub fn fill(self: *Self, value: T) void {
            @memset(self.data, value);
        }

        /// Get the total number of elements in the array.
        pub fn len(self: Self) usize {
            return self.data.len;
        }
    };
}

test "MultiDimArray 2D basic operations" {
    const allocator = std.testing.allocator;

    var arr = try MultiDimArray(i32).init(allocator, &[_]usize{ 3, 4 });
    defer arr.deinit();

    arr.set(&[_]usize{ 0, 0 }, 10);
    arr.set(&[_]usize{ 1, 2 }, 42);
    arr.set(&[_]usize{ 2, 3 }, 99);

    try std.testing.expectEqual(@as(i32, 10), arr.get(&[_]usize{ 0, 0 }));
    try std.testing.expectEqual(@as(i32, 42), arr.get(&[_]usize{ 1, 2 }));
    try std.testing.expectEqual(@as(i32, 99), arr.get(&[_]usize{ 2, 3 }));
}

test "MultiDimArray 3D with tuple syntax" {
    const allocator = std.testing.allocator;

    var arr = try MultiDimArray(i32).init(allocator, &[_]usize{ 2, 3, 4 });
    defer arr.deinit();

    arr.setAt(.{ 0, 0, 0 }, 1);
    arr.setAt(.{ 1, 2, 3 }, 123);

    try std.testing.expectEqual(@as(i32, 1), arr.getAt(.{ 0, 0, 0 }));
    try std.testing.expectEqual(@as(i32, 123), arr.getAt(.{ 1, 2, 3 }));
}

test "MultiDimArray fill" {
    const allocator = std.testing.allocator;

    var arr = try MultiDimArray(i32).init(allocator, &[_]usize{ 2, 3 });
    defer arr.deinit();

    arr.fill(7);

    for (0..2) |i| {
        for (0..3) |j| {
            try std.testing.expectEqual(@as(i32, 7), arr.get(&[_]usize{ i, j }));
        }
    }
}

test "MultiDimArray pointer modification" {
    const allocator = std.testing.allocator;

    var arr = try MultiDimArray(i32).init(allocator, &[_]usize{ 2, 2 });
    defer arr.deinit();

    const ptr = arr.getPtr(&[_]usize{ 1, 1 });
    ptr.* = 55;

    try std.testing.expectEqual(@as(i32, 55), arr.get(&[_]usize{ 1, 1 }));
}
