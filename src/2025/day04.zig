const std = @import("std");

var buf: [2048]u8 = undefined;
const size = 136;

pub fn part1(input: []const u8) ![]const u8 {
    var world: [size][size]i32 = [_][size]i32{[_]i32{0} ** size} ** size;
    var itrow = std.mem.splitAny(u8, input[0 .. input.len - 1], "\n");
    var irow: usize = 0;
    while (itrow.next()) |row| {
        for (row, 0..) |c, icol| {
            if (c == '@')
                world[irow][icol] = 1;
        }
        irow += 1;
    }
    var num_accessible: i32 = 0;
    const deltas = [_]i32{ -1, 0, 1 };
    for (0..size) |i| {
        for (0..size) |j| {
            if (world[i][j] == 0) continue;
            var neighbors: i32 = 0;
            for (deltas) |di| {
                for (deltas) |dj| {
                    if (di == 0 and dj == 0) continue;
                    const ii = @as(i32, @intCast(i)) + di;
                    const jj = @as(i32, @intCast(j)) + dj;
                    if (ii >= 0 and ii < size and jj >= 0 and jj < size) {
                        neighbors += world[@intCast(ii)][@intCast(jj)];
                    }
                }
            }
            if (neighbors < 4) num_accessible += 1;
        }
    }
    return std.fmt.bufPrint(&buf, "{d}", .{num_accessible}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    var world: [size][size]i32 = [_][size]i32{[_]i32{0} ** size} ** size;
    var itrow = std.mem.splitAny(u8, input[0 .. input.len - 1], "\n");
    var irow: usize = 0;
    while (itrow.next()) |row| {
        for (row, 0..) |c, icol| {
            if (c == '@')
                world[irow][icol] = 1;
        }
        irow += 1;
    }
    var next_world = world;
    var num_accessible: i32 = 0;
    const deltas = [_]i32{ -1, 0, 1 };
    var has_removed = true;
    while (has_removed) {
        has_removed = false;
        next_world = world;
        for (0..size) |i| {
            for (0..size) |j| {
                if (world[i][j] == 0) continue;
                var neighbors: i32 = 0;
                for (deltas) |di| {
                    for (deltas) |dj| {
                        if (di == 0 and dj == 0) continue;
                        const ii = @as(i32, @intCast(i)) + di;
                        const jj = @as(i32, @intCast(j)) + dj;
                        if (ii >= 0 and ii < size and jj >= 0 and jj < size) {
                            neighbors += world[@intCast(ii)][@intCast(jj)];
                        }
                    }
                }
                if (neighbors < 4) {
                    num_accessible += 1;
                    has_removed = true;
                    next_world[i][j] = 0;
                }
            }
        }
        world = next_world;
    }
    return std.fmt.bufPrint(&buf, "{d}", .{num_accessible}) catch "error";
}
