const std = @import("std");
const lib = @import("lib");
const splitOnce = lib.str_utils.splitOnce;

var buf: [2048]u8 = undefined;

const shape_size: usize = 3;
const num_shapes: usize = 6;
const ShapeMask = [shape_size][shape_size]bool;
const Shape = struct {
    const Self = @This();
    id: usize,
    mask: ShapeMask,
    area: usize,
};
const max_num_rect: usize = 1000;
const Rect = struct {
    width: usize,
    height: usize,
    shape_count: [num_shapes]usize,
};

pub fn part1(input: []const u8) ![]const u8 {
    var shapes: [num_shapes]Shape = undefined;

    var it = std.mem.splitScalar(u8, input[0 .. input.len - 1], '\n');

    // Parsing shapes
    var shape_counter: usize = 0;
    while (it.next()) |line| {
        const shape_id = std.fmt.parseInt(usize, line[0..1], 10) catch unreachable;
        var mask: ShapeMask = undefined;
        var area: usize = 0;
        for (0..shape_size) |i| {
            if (it.next()) |row| {
                for (0..shape_size) |j| {
                    if (row[j] == '#') {
                        mask[i][j] = true;
                        area += 1;
                    } else {
                        mask[i][j] = false;
                    }
                }
            }
        }
        shapes[shape_counter] = .{ .id = shape_id, .mask = mask, .area = area };
        _ = it.next();
        shape_counter += 1;
        if (shape_counter == num_shapes) {
            break;
        }
    }

    var rects: [max_num_rect]Rect = undefined;
    var num_rect: usize = 0;
    while (it.next()) |line| : (num_rect += 1) {
        const parts = splitOnce(line, ':');

        const sizes = splitOnce(parts.before, 'x');
        const width = std.fmt.parseInt(usize, sizes.before, 10) catch unreachable;
        const height = std.fmt.parseInt(usize, sizes.after, 10) catch unreachable;

        var count_it = std.mem.splitScalar(u8, parts.after, ' ');
        var count_i: usize = 0;
        var counts: [num_shapes]usize = undefined;
        while (count_it.next()) |count_str| {
            if (count_str.len == 0) continue;
            const count = std.fmt.parseInt(usize, count_str, 10) catch unreachable;
            counts[count_i] = count;
            count_i += 1;
        }
        rects[num_rect] = .{ .width = width, .height = height, .shape_count = counts };
    }

    var does_not_fit: usize = 0;
    for (0..num_rect) |i| {
        const rect = rects[i];
        const area = rect.width * rect.height;
        var present_area: usize = 0;
        for (0..num_shapes) |j| {
            const shape = shapes[j];
            const present_count = rect.shape_count[j];
            present_area += shape.area * present_count;
        }
        if (present_area < area) {
            does_not_fit += 1;
        }
    }

    if (num_rect < 10) {
        return std.fmt.bufPrint(&buf, "The example is a troll, the answer is 2", .{}) catch "error";
    } else {
        return std.fmt.bufPrint(&buf, "{d}", .{does_not_fit}) catch "error";
    }
}

pub fn part2(input: []const u8) ![]const u8 {
    _ = input;
    // Your solution here
    return std.fmt.bufPrint(&buf, "No part 2 today ;)", .{}) catch "error";
}
