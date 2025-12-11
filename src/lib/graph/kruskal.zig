const std = @import("std");
const Allocator = std.mem.Allocator;
const graph = @import("graph.zig");

pub const Edge = graph.Edge;

pub const DSU = struct {
    const This = @This();
    parent: []usize,
    rank: []usize,
    allocator: Allocator,

    /// Allocate and initialize disjoint-set storage for `num_elements` nodes.
    pub fn init(allocator: Allocator, num_elements: usize) !This {
        const parent = try allocator.alloc(usize, num_elements);
        const rank_arr = try allocator.alloc(usize, num_elements);
        for (0..num_elements) |i| {
            parent[i] = i; // Every element is its own parent initially
            rank_arr[i] = 0; // Initial rank is 0
        }
        return DSU{
            .parent = parent,
            .rank = rank_arr,
            .allocator = allocator,
        };
    }

    /// Release allocated DSU buffers.
    pub fn deinit(self: This) void {
        self.allocator.free(self.parent);
        self.allocator.free(self.rank);
    }

    /// Find the representative for `i`, performing path compression.
    pub fn find(self: *This, i: usize) usize {
        if (self.parent[i] != i) {
            self.parent[i] = self.find(self.parent[i]);
        }
        return self.parent[i];
    }

    /// Union the sets containing `i` and `j`; return true if merged.
    pub fn conj(self: *DSU, i: usize, j: usize) bool {
        const root_i = self.find(i);
        const root_j = self.find(j);

        if (root_i != root_j) {
            if (self.rank[root_i] < self.rank[root_j]) {
                self.parent[root_i] = root_j;
            } else if (self.rank[root_i] > self.rank[root_j]) {
                self.parent[root_j] = root_i;
            } else {
                self.parent[root_j] = root_i;
                self.rank[root_i] += 1;
            }
            return true;
        }
        return false;
    }
};

/// Compare two edges by weight for ascending sort.
pub fn compareEdges(context: void, a: Edge, b: Edge) bool {
    _ = context;
    return a.weight < b.weight;
}

/// Build a minimum spanning tree from `vertices` using Kruskal's algorithm and
/// return the selected edges in ascending weight order.
pub fn kruskal(comptime V: type, allocator: Allocator, vertices: []const V, weight_fn: fn (V, V) f32) !std.ArrayList(Edge) {
    const num_vertices = vertices.len;

    // Generate all unique undirected edges.
    var all_edges = try std.ArrayList(Edge).initCapacity(allocator, num_vertices * (num_vertices - 1) / 2);
    errdefer all_edges.deinit(allocator);

    for (0..num_vertices) |i| {
        for (i + 1..num_vertices) |j| {
            const weight = weight_fn(vertices[i], vertices[j]);
            try all_edges.append(allocator, Edge{ .u = i, .v = j, .weight = weight });
        }
    }

    // Sort edges so we can greedily pick the lightest non-cycling ones.
    std.mem.sort(Edge, all_edges.items, {}, compareEdges);

    // Collect edges that end up in the MST.
    var mst_edges = try std.ArrayList(Edge).initCapacity(allocator, num_vertices - 1);
    errdefer mst_edges.deinit(allocator);

    var dsu = try DSU.init(allocator, num_vertices);
    defer dsu.deinit();

    var edges_count: usize = 0;
    const max_edges = num_vertices - 1;

    for (all_edges.items) |edge| {
        if (edges_count == max_edges) {
            break;
        }

        // Add edge if it connects two different components.
        if (dsu.conj(edge.u, edge.v)) {
            try mst_edges.append(allocator, edge);
            edges_count += 1;
        }
    }

    all_edges.deinit(allocator);
    return mst_edges;
}

// Unit tests
test "DSU union and find" {
    const allocator = std.testing.allocator;

    var dsu = try DSU.init(allocator, 5);
    defer dsu.deinit();

    try std.testing.expectEqual(dsu.find(0), 0);
    try std.testing.expectEqual(dsu.find(1), 1);

    try std.testing.expect(dsu.conj(0, 1));
    try std.testing.expectEqual(dsu.find(0), dsu.find(1));

    try std.testing.expect(dsu.conj(1, 2));
    try std.testing.expectEqual(dsu.find(0), dsu.find(2));

    try std.testing.expect(!dsu.conj(0, 1));
}

test "Kruskal simple MST" {
    const allocator = std.testing.allocator;

    const Point = struct {
        x: i32,
        y: i32,
    };

    const dist = struct {
        fn f(a: Point, b: Point) f32 {
            const dx = @as(f32, @floatFromInt(a.x - b.x));
            const dy = @as(f32, @floatFromInt(a.y - b.y));
            return std.math.sqrt(dx * dx + dy * dy);
        }
    }.f;

    var verts = [_]Point{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 2, .y = 0 },
    };

    var mst = try kruskal(Point, allocator, &verts, dist);
    defer mst.deinit(allocator);

    try std.testing.expectEqual(mst.items.len, 2);

    var total: f32 = 0;
    for (mst.items) |e| total += e.weight;
    try std.testing.expectApproxEqAbs(total, 2.0, 0.0001);
}
