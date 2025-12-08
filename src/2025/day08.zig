const std = @import("std");
const lib = @import("lib");
const min_heap = lib.min_heap;
const kruskal = lib.kruskal;

var buf: [2048]u8 = undefined;

const Point = struct {
    x: i32,
    y: i32,
    z: i32,
};
const size: usize = 1000;

pub fn pointDistance(p1: Point, p2: Point) f32 {
    const dx = @as(f32, @floatFromInt(p1.x - p2.x));
    const dy = @as(f32, @floatFromInt(p1.y - p2.y));
    const dz = @as(f32, @floatFromInt(p1.z - p2.z));

    return std.math.sqrt(dx * dx + dy * dy + dz * dz);
}

const Connection = struct {
    from: usize,
    to: usize,
    distance: f32,
};

fn connectionComparator(context: void, a: Connection, b: Connection) bool {
    _ = context;
    return a.distance < b.distance;
}

pub fn part1(input: []const u8) ![]const u8 {
    var points = [_]Point{.{ .x = 0, .y = 0, .z = 0 }} ** size;
    var numPoints: usize = 0;

    var it = std.mem.splitAny(u8, input, "\n");
    while (it.next()) |line| {
        var parts = std.mem.splitAny(u8, line, ",");
        if (parts.next()) |x| {
            if (parts.next()) |y| {
                if (parts.next()) |z| {
                    const zz = std.mem.trim(u8, z, " \n");
                    points[numPoints] = Point{ .x = try std.fmt.parseInt(i32, x, 10), .y = try std.fmt.parseInt(i32, y, 10), .z = try std.fmt.parseInt(i32, zz, 10) };
                    numPoints += 1;
                }
            }
        }
    }
    const alloc = std.heap.page_allocator;

    const ConnMinHeap = min_heap.MinHeap(Connection, connectionComparator);
    var heap = ConnMinHeap.init(alloc, {});
    defer heap.deinit();

    for (0..numPoints) |i| {
        for (i + 1..numPoints) |j| {
            const dist = pointDistance(points[i], points[j]);
            try heap.push(Connection{ .from = i, .to = j, .distance = dist });
        }
    }

    var maxConnections: usize = 10;
    if (numPoints > 100) {
        maxConnections = 1000;
    }

    var circuit = [_]usize{0} ** size;
    var numCircuits: usize = 0;
    for (0..maxConnections) |_| {
        const conn = heap.pop().?;

        const c1 = circuit[conn.from];
        const c2 = circuit[conn.to];

        if (c1 == 0 and c2 == 0) {
            // New circuit
            numCircuits += 1;
            circuit[conn.from] = numCircuits;
            circuit[conn.to] = numCircuits;
        } else if (c1 == 0) {
            // Merge with second circuit
            circuit[conn.from] = c2;
        } else if (c2 == 0) {
            // Merge with first circuit
            circuit[conn.to] = c1;
        } else if (c1 == c2) {
            // Already in same circuit
        } else {
            // Merge circuits - rename higher circuit to lower circuit
            const keepCircuit = @min(c1, c2);
            const removeCircuit = @max(c1, c2);
            for (0..numPoints) |i| {
                if (circuit[i] == removeCircuit) {
                    circuit[i] = keepCircuit;
                }
            }
        }
    }

    var map = std.AutoHashMap(usize, usize).init(alloc);
    defer map.deinit();
    for (0..numPoints) |i| {
        if (circuit[i] == 0) continue; // Skip points not in any circuit
        const entry = try map.getOrPut(circuit[i]);
        if (!entry.found_existing) {
            entry.value_ptr.* = 1;
        } else {
            entry.value_ptr.* += 1;
        }
    }

    var counts = try std.ArrayList(usize).initCapacity(alloc, 100);
    defer counts.deinit(alloc);

    var vit = map.valueIterator();
    while (vit.next()) |value| {
        try counts.append(alloc, value.*);
    }

    std.mem.sort(usize, counts.items, {}, comptime std.sort.desc(usize));

    const top1 = if (counts.items.len > 0) counts.items[0] else 0;
    const top2 = if (counts.items.len > 1) counts.items[1] else 0;
    const top3 = if (counts.items.len > 2) counts.items[2] else 0;

    return std.fmt.bufPrint(&buf, "{d}", .{top1 * top2 * top3}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    var points = [_]Point{.{ .x = 0, .y = 0, .z = 0 }} ** size;
    var numPoints: usize = 0;

    var it = std.mem.splitAny(u8, input, "\n");
    while (it.next()) |line| {
        var parts = std.mem.splitAny(u8, line, ",");
        if (parts.next()) |x| {
            if (parts.next()) |y| {
                if (parts.next()) |z| {
                    const zz = std.mem.trim(u8, z, " \n");
                    points[numPoints] = Point{ .x = try std.fmt.parseInt(i32, x, 10), .y = try std.fmt.parseInt(i32, y, 10), .z = try std.fmt.parseInt(i32, zz, 10) };
                    numPoints += 1;
                }
            }
        }
    }
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var mst_edges = try kruskal.kruskal(
        Point,
        allocator,
        points[0..numPoints],
        pointDistance,
    );
    defer mst_edges.deinit(allocator);

    if (mst_edges.items.len > 0) {
        const last_edge = mst_edges.items[mst_edges.items.len - 1];
        const p1 = points[last_edge.u];
        const p2 = points[last_edge.v];
        return std.fmt.bufPrint(&buf, "{d}", .{p1.x * p2.x}) catch "error";
    }

    return std.fmt.bufPrint(&buf, "{d}", .{0}) catch "error";
}
