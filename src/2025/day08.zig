const std = @import("std");

var buf: [2048]u8 = undefined;

const Point = struct {
    x: i32,
    y: i32,
    z: i32,
};
const size: usize = 1000;

pub fn distance(p1: Point, p2: Point) f64 {
    const dx = @as(f64, @floatFromInt(p1.x - p2.x));
    const dy = @as(f64, @floatFromInt(p1.y - p2.y));
    const dz = @as(f64, @floatFromInt(p1.z - p2.z));

    return std.math.sqrt(dx * dx + dy * dy + dz * dz);
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

    var maxConnections: usize = 10;
    if (numPoints > 100) {
        maxConnections = 1000;
    }

    var numCircuits: usize = 0;
    var circuit = [_]usize{0} ** size;
    var wereMatched = [_][size]bool{[_]bool{false} ** size} ** size;
    var numConnections: usize = 0;
    while (true) {
        if (numConnections == maxConnections)
            break;
        var firstIdx: usize = undefined;
        var secondIdx: usize = undefined;
        var minDistance: f64 = std.math.inf(f64);
        var didMatch: bool = false;
        for (0..numPoints - 1) |i| {
            for (i + 1..numPoints) |j| {
                if (wereMatched[i][j]) continue;
                const dist = distance(points[i], points[j]);
                if (dist < minDistance) {
                    minDistance = dist;
                    firstIdx = i;
                    secondIdx = j;
                    didMatch = true;
                }
            }
        }
        if (!didMatch) break;

        numConnections += 1;

        wereMatched[firstIdx][secondIdx] = true;
        wereMatched[secondIdx][firstIdx] = true;

        const c1 = circuit[firstIdx];
        const c2 = circuit[secondIdx];

        if (c1 == 0 and c2 == 0) {
            // New circuit
            numCircuits += 1;
            circuit[firstIdx] = numCircuits;
            circuit[secondIdx] = numCircuits;
        } else if (c1 == 0) {
            // Merge with second circuit
            circuit[firstIdx] = c2;
        } else if (c2 == 0) {
            // Merge with first circuit
            circuit[secondIdx] = c1;
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
    var map = std.AutoHashMap(usize, usize).init(std.heap.page_allocator);
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

    var counts = try std.ArrayList(usize).initCapacity(std.heap.page_allocator, 100);
    defer counts.deinit(std.heap.page_allocator);

    var vit = map.valueIterator();
    while (vit.next()) |value| {
        try counts.append(std.heap.page_allocator, value.*);
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

    var numCircuits: usize = 0;
    var circuit = [_]usize{0} ** size;
    var wereMatched = [_][size]bool{[_]bool{false} ** size} ** size;
    var numConnections: usize = 0;
    var lastConnection: [2]i32 = undefined;
    while (true) {
        var allConnected = true;
        const c = circuit[0];
        if (c != 0) {
            for (1..numPoints) |i| {
                if (circuit[i] != c) {
                    allConnected = false;
                    break;
                }
            }
        } else {
            allConnected = false;
        }
        if (allConnected) break;
        var firstIdx: usize = undefined;
        var secondIdx: usize = undefined;
        var minDistance: f64 = std.math.inf(f64);
        var didMatch: bool = false;
        for (0..numPoints - 1) |i| {
            for (i + 1..numPoints) |j| {
                if (wereMatched[i][j]) continue;
                const dist = distance(points[i], points[j]);
                if (dist < minDistance) {
                    minDistance = dist;
                    firstIdx = i;
                    secondIdx = j;
                    didMatch = true;
                }
            }
        }
        if (!didMatch) break;

        numConnections += 1;

        wereMatched[firstIdx][secondIdx] = true;
        wereMatched[secondIdx][firstIdx] = true;

        const c1 = circuit[firstIdx];
        const c2 = circuit[secondIdx];

        if (c1 == 0 and c2 == 0) {
            // New circuit
            numCircuits += 1;
            circuit[firstIdx] = numCircuits;
            circuit[secondIdx] = numCircuits;
        } else if (c1 == 0) {
            // Merge with second circuit
            circuit[firstIdx] = c2;
        } else if (c2 == 0) {
            // Merge with first circuit
            circuit[secondIdx] = c1;
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

        const p1 = points[firstIdx];
        const p2 = points[secondIdx];
        lastConnection = [_]i32{ p1.x, p2.x };
    }

    return std.fmt.bufPrint(&buf, "{d}", .{lastConnection[0] * lastConnection[1]}) catch "error";
}
