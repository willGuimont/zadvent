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

    pub fn deinit(self: This) void {
        self.allocator.free(self.parent);
        self.allocator.free(self.rank);
    }

    pub fn find(self: *This, i: usize) usize {
        if (self.parent[i] != i) {
            self.parent[i] = self.find(self.parent[i]);
        }
        return self.parent[i];
    }

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

pub fn compareEdges(context: void, a: Edge, b: Edge) bool {
    _ = context;
    return a.weight < b.weight;
}

pub fn kruskal(comptime V: type, allocator: Allocator, vertices: []const V, weight_fn: fn (V, V) f32) !std.ArrayList(Edge) {
    const num_vertices = vertices.len;

    var all_edges = try std.ArrayList(Edge).initCapacity(allocator, num_vertices * (num_vertices - 1) / 2);
    errdefer all_edges.deinit(allocator);

    for (0..num_vertices) |i| {
        for (i + 1..num_vertices) |j| {
            const weight = weight_fn(vertices[i], vertices[j]);
            try all_edges.append(allocator, Edge{ .u = i, .v = j, .weight = weight });
        }
    }

    std.mem.sort(Edge, all_edges.items, {}, compareEdges);

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

        if (dsu.conj(edge.u, edge.v)) {
            try mst_edges.append(allocator, edge);
            edges_count += 1;
        }
    }

    all_edges.deinit(allocator);
    return mst_edges;
}
