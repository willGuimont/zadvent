const std = @import("std");
const lib = @import("lib");
const splitOnce = lib.str_utils.splitOnce;
const geometry = lib.math.geometry;
const multidim = lib.ds.multidim_array;

var buf: [2048]u8 = undefined;
const size: usize = 497;
const Point = struct { x: i64, y: i64 };

pub fn part1(input: []const u8) ![]const u8 {
    var points: [size]Point = undefined;
    var it = std.mem.splitScalar(u8, input[0 .. input.len - 1], '\n');
    var num_points: usize = 0;
    while (it.next()) |line| {
        const pair = splitOnce(line, ',');
        const x = try std.fmt.parseInt(i64, pair.before, 10);
        const y = try std.fmt.parseInt(i64, pair.after, 10);
        points[num_points] = Point{ .x = x, .y = y };
        num_points += 1;
    }
    var max_area: u64 = 0;
    for (0..num_points) |i| {
        for (i + 1..num_points) |j| {
            const dx = @abs(points[i].x - points[j].x) + 1;
            const dy = @abs(points[i].y - points[j].y) + 1;
            const area = @as(u64, @intCast(dx)) * @as(u64, @intCast(dy));
            if (area > max_area) max_area = area;
        }
    }
    return std.fmt.bufPrint(&buf, "{d}", .{max_area}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    var points: [size]Point = undefined;
    var it = std.mem.splitScalar(u8, input[0 .. input.len - 1], '\n');
    var num_points: usize = 0;
    while (it.next()) |line| {
        const pair = splitOnce(line, ',');
        const x = try std.fmt.parseInt(i64, pair.before, 10);
        const y = try std.fmt.parseInt(i64, pair.after, 10);
        points[num_points] = Point{ .x = x, .y = y };
        num_points += 1;
    }

    var edges: [size]geometry.Edge = undefined;
    var num_edges: usize = 0;

    if (num_points >= 2) {
        for (0..num_points - 1) |k| {
            edges[num_edges] = geometry.Edge{
                .x1 = points[k].x,
                .y1 = points[k].y,
                .x2 = points[k + 1].x,
                .y2 = points[k + 1].y,
            };
            num_edges += 1;
        }

        // Close loop
        edges[num_edges] = geometry.Edge{
            .x1 = points[0].x,
            .y1 = points[0].y,
            .x2 = points[num_points - 1].x,
            .y2 = points[num_points - 1].y,
        };
        num_edges += 1;
    }
    const polygon = geometry.Polygon{
        .edges = edges[0..num_edges],
    };

    var max_area: u64 = 0;
    for (0..num_points) |i| {
        for (i + 1..num_points) |j| {
            const dx = @abs(points[i].x - points[j].x) + 1;
            const dy = @abs(points[i].y - points[j].y) + 1;
            const area = @as(u64, @intCast(dx)) * @as(u64, @intCast(dy));

            if (area > max_area) {
                const min_x = @min(points[i].x, points[j].x);
                const max_x = @max(points[i].x, points[j].x);
                const min_y = @min(points[i].y, points[j].y);
                const max_y = @max(points[i].y, points[j].y);

                if (!polygon.intersectsAabb(min_x, min_y, max_x, max_y)) {
                    max_area = area;
                }
            }
        }
    }

    return std.fmt.bufPrint(&buf, "{d}", .{max_area}) catch "error";
}
