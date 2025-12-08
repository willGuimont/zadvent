const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Edge = struct {
    u: usize,
    v: usize,
    weight: f32,
};

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
