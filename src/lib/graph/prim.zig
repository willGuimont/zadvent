const std = @import("std");
const Allocator = std.mem.Allocator;
const graph = @import("graph.zig");

pub const Edge = graph.Edge;

/// Prim's algorithm for dense graphs using O(n^2) time and O(n) memory.
///
/// This variant assumes the graph is complete: there is an edge between
/// every pair of vertices, and the weight is provided by `weight_fn`.
/// It returns the MST edges in the order they are added.
///
/// The caller must ensure that `max_vertices` is >= vertices.len.
/// This is used to size the internal fixed arrays on the stack.
pub fn prim_complete(
    comptime V: type,
    comptime max_vertices: usize,
    allocator: Allocator,
    vertices: []const V,
    weight_fn: fn (V, V) f32,
) !std.ArrayList(Edge) {
    const n = vertices.len;
    if (n == 0) {
        return std.ArrayList(Edge).initCapacity(allocator, 0);
    }
    if (n > max_vertices) {
        return error.TooManyVertices;
    }

    var in_mst = [_]bool{false} ** max_vertices;
    var min_dist = [_]f32{std.math.inf(f32)} ** max_vertices;
    var parent = [_]usize{0} ** max_vertices;

    min_dist[0] = 0;
    parent[0] = 0;

    var mst_edges = try std.ArrayList(Edge).initCapacity(allocator, if (n > 0) n - 1 else 0);
    errdefer mst_edges.deinit(allocator);

    var added: usize = 0;
    while (added < n) {
        var u: usize = 0;
        var best = std.math.inf(f32);
        var found = false;
        for (0..n) |i| {
            if (!in_mst[i] and min_dist[i] < best) {
                best = min_dist[i];
                u = i;
                found = true;
            }
        }

        if (!found) break; // Disconnected graph

        in_mst[u] = true;
        if (added != 0) {
            try mst_edges.append(allocator, Edge{
                .u = u,
                .v = parent[u],
                .weight = min_dist[u],
            });
        }
        added += 1;

        for (0..n) |v| {
            if (in_mst[v]) continue;
            const w = weight_fn(vertices[u], vertices[v]);
            if (w < min_dist[v]) {
                min_dist[v] = w;
                parent[v] = u;
            }
        }
    }

    return mst_edges;
}
