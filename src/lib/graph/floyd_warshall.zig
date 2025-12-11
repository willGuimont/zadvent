const std = @import("std");
const multimdim_array = @import("../ds/multidim_array.zig");

/// All-pairs shortest paths using the Floyd–Warshall algorithm.
///
/// Stores an adjacency matrix of `Weight` values and lazily computes the
/// distance matrix on first call to `run` or `distanceBetween`.
///
/// The `Weight` type must be an integer or floating-point type.
/// Unreachable pairs use an implicit `Inf` value derived from `Weight`.
///
/// Example:
///   const FW = FloydWarshall(i32);
///   var graph = try FW.init(allocator, 4);
///   defer graph.deinit();
///   try graph.addEdge(0, 1, 5);
///   try graph.addEdge(1, 2, 2);
///   const d = try graph.distanceBetween(0, 2); // == 7
pub fn FloydWarshall(comptime Weight: type) type {
    return struct {
        const Self = @This();
        const Array = multimdim_array.MultiDimArray(Weight);
        pub const Inf: Weight = blk: {
            const ti = @typeInfo(Weight);
            switch (ti) {
                .float, .comptime_float => break :blk std.math.inf(Weight),
                .int, .comptime_int => break :blk std.math.maxInt(Weight),
                else => @compileError("FloydWarshall requires an integer or float numeric type for weights"),
            }
        };
        const Index = usize;

        size: usize,
        weights: Array,
        distances: ?Array,
        allocator: std.mem.Allocator,

        /// Create a new `size x size` graph with all edges initially unreachable.
        pub fn init(allocator: std.mem.Allocator, size: usize) !Self {
            return Self{
                .size = size,
                .weights = try Array.initDefault(allocator, &[_]usize{ size, size }, Inf),
                .distances = null,
                .allocator = allocator,
            };
        }

        /// Free all internal buffers. The graph must not be used afterwards.
        pub fn deinit(self: *Self) void {
            self.weights.deinit();
            if (self.distances) |*distances| {
                distances.deinit();
            }
        }

        /// Add or update a directed edge `from -> to` with the given weight.
        /// Invalidates any previously computed distance matrix.
        pub fn addEdge(self: *Self, from: Index, to: Index, weight: Weight) !void {
            self.weights.setAt(.{ from, to }, weight);
            self.distances = null;
        }

        /// Add or update an undirected edge between `from` and `to`.
        pub fn addUndirectedEdge(self: *Self, from: Index, to: Index, weight: Weight) !void {
            try self.addEdge(from, to, weight);
            try self.addEdge(to, from, weight);
        }

        /// Remove the directed edge `from -> to` (mark as unreachable).
        /// Invalidates any previously computed distance matrix.
        pub fn removeEdge(self: *Self, from: Index, to: Index) !void {
            self.weights.setAt(.{ from, to }, Inf);
            self.distances = null;
        }

        /// Remove both directions of an undirected edge between `from` and `to`.
        pub fn removeUndirectedEdge(self: *Self, from: Index, to: Index) !void {
            try self.removeEdge(from, to);
            try self.removeEdge(to, from);
        }

        /// Get the length of the shortest path from `from` to `to`.
        ///
        /// Triggers `run` on first call or after any mutation that invalidated
        /// the cached distances. If no path exists, returns `Inf`.
        pub fn distanceBetween(self: *Self, from: Index, to: Index) !Weight {
            try self.run();
            const distances = self.distances.?;
            return distances.getAt(.{ from, to });
        }

        /// Return whether there is an explicit edge `from -> to` in the
        /// underlying adjacency matrix (ignores paths via other nodes).
        pub fn hasEdge(self: *Self, from: Index, to: Index) bool {
            return self.weights.getAt(.{ from, to }) != Inf;
        }

        /// Return whether there exists any path from `from` to `to`.
        ///
        /// This uses the all-pairs distances, so it will trigger `run` on the
        /// first call (or after mutations) via `distanceBetween`.
        pub fn hasPath(self: *Self, from: Index, to: Index) !bool {
            const distance = try self.distanceBetween(from, to);
            return distance != Inf;
        }

        /// Compute all-pairs shortest paths if not already cached.
        /// Subsequent calls are no-ops until the graph is mutated again.
        pub fn run(self: *Self) !void {
            if (self.distances != null) return;
            const n = self.size;
            var distances = try Array.init(self.allocator, &[_]usize{ n, n });
            for (0..n) |i| {
                for (0..n) |j| {
                    const pos = .{ i, j };
                    distances.setAt(pos, self.weights.getAt(pos));
                }
            }
            for (0..n) |i| {
                distances.setAt(.{ i, i }, 0);
            }

            for (0..n) |k| { // Intermediate node
                for (0..n) |i| { // Starting node
                    const start_to_inter = .{ i, k };
                    const start_to_inter_weight = distances.getAt(start_to_inter);
                    for (0..n) |j| { // Ending node
                        const start_to_end = .{ i, j };
                        const inter_to_end = .{ k, j };
                        const start_to_end_weight = distances.getAt(start_to_end);
                        const inter_to_end_weight = distances.getAt(inter_to_end);
                        const other_path_weight = if (start_to_inter_weight == Inf or inter_to_end_weight == Inf) Inf else start_to_inter_weight + inter_to_end_weight;
                        distances.setAt(start_to_end, @min(start_to_end_weight, other_path_weight));
                    }
                }
            }
            self.distances = distances;
        }
    };
}

test "FloydWarshall computes shortest paths" {
    const allocator = std.testing.allocator;
    const size = 4;
    var graph = try FloydWarshall(i32).init(allocator, size);
    defer graph.deinit();

    // Graph:
    // 0 -> 1 (5), 1 -> 2 (2), 0 -> 2 (10), 2 -> 3 (1)
    try graph.addEdge(0, 1, 5);
    try graph.addEdge(1, 2, 2);
    try graph.addEdge(0, 2, 10);
    try graph.addEdge(2, 3, 1);

    try graph.run();

    // Shortest 0 -> 2 should be 5 + 2 = 7 (not 10)
    const dist_0_2 = try graph.distanceBetween(0, 2);
    try std.testing.expectEqual(@as(i32, 7), dist_0_2);

    // Shortest 0 -> 3 should be 5 + 2 + 1 = 8
    const dist_0_3 = try graph.distanceBetween(0, 3);
    try std.testing.expectEqual(@as(i32, 8), dist_0_3);

    // Distance from a node to itself should be 0
    const dist_1_1 = try graph.distanceBetween(1, 1);
    try std.testing.expectEqual(@as(i32, 0), dist_1_1);
}

test "FloydWarshall disconnected components have no path" {
    const allocator = std.testing.allocator;
    const size = 4;
    const FW = FloydWarshall(f32);
    const Inf = FW.Inf;

    var graph = try FW.init(allocator, size);
    defer graph.deinit();

    // Component 1: 0 <-> 1, Component 2: 2 <-> 3
    try graph.addUndirectedEdge(0, 1, 3.5);
    try graph.addUndirectedEdge(2, 3, 4.1);

    try graph.run();

    // There should be no path between components: 0 <-> 2, 1 <-> 3, etc.
    const dist_0_2 = try graph.distanceBetween(0, 2);
    const dist_1_3 = try graph.distanceBetween(1, 3);

    try std.testing.expectEqual(Inf, dist_0_2);
    try std.testing.expectEqual(Inf, dist_1_3);
}
