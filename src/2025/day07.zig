const std = @import("std");

var buf: [2048]u8 = undefined;
const size: usize = 143;

pub fn part1(input: []const u8) ![]const u8 {
    var world: [size][size]u8 = undefined;
    var actual_size: usize = 0;

    var it = std.mem.splitAny(u8, input, "\n");
    var line_num: usize = 0;
    while (it.next()) |line| {
        actual_size = @max(actual_size, line.len);
        @memcpy(world[line_num][0..line.len], line);
        line_num += 1;
    }

    const starting_point = std.mem.indexOf(u8, &world[0], "S").?;
    var current_line = [_]u8{'.'} ** size;
    current_line[starting_point] = '|';

    var num_splits: usize = 0;
    for (1..actual_size) |lineIdx| {
        const world_line = world[lineIdx];
        var next_line = [_]u8{'.'} ** size;
        for (0..actual_size) |i| {
            if (current_line[i] == '|') {
                if (world_line[i] == '^') {
                    next_line[i - 1] = '|';
                    next_line[i + 1] = '|';
                    num_splits += 1;
                } else {
                    next_line[i] = '|';
                }
            }
        }
        current_line = next_line;
    }

    return std.fmt.bufPrint(&buf, "{d}", .{num_splits}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    var world: [size][size]u8 = undefined;
    var actual_size: usize = 0;

    var it = std.mem.splitAny(u8, input, "\n");
    var line_num: usize = 0;
    while (it.next()) |line| {
        actual_size = @max(actual_size, line.len);
        @memcpy(world[line_num][0..line.len], line);
        line_num += 1;
    }

    const starting_point = std.mem.indexOf(u8, &world[0], "S").?;
    var current_line = [_]i64{0} ** size;
    current_line[starting_point] = 1;

    for (1..actual_size) |lineIdx| {
        const world_line = world[lineIdx];
        var next_line = [_]i64{0} ** size;
        for (0..actual_size) |i| {
            const num_beams = current_line[i];
            if (num_beams > 0) {
                if (world_line[i] == '^') {
                    next_line[i - 1] += num_beams;
                    next_line[i + 1] += num_beams;
                } else {
                    next_line[i] += num_beams;
                }
            }
        }
        current_line = next_line;
    }

    var total_path: i64 = 0;
    for (0..actual_size) |i| {
        total_path += current_line[i];
    }

    return std.fmt.bufPrint(&buf, "{d}", .{total_path}) catch "error";
}
