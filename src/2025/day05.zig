const std = @import("std");
const splitOnce = @import("lib").str_utils.splitOnce;

var buf: [2048]u8 = undefined;
const size = 200;

const Range = struct {
    start: i64,
    end: i64,
    valid: bool,
};

pub fn part1(input: []const u8) ![]const u8 {
    var ranges: [size]Range = undefined;
    var it = std.mem.splitScalar(u8, input[0 .. input.len - 1], '\n');
    var range_count: usize = 0;
    while (it.next()) |part| {
        if (part.len == 0) break;
        const range = splitOnce(part, '-');
        const start = try std.fmt.parseInt(i64, range.before, 10);
        const end = try std.fmt.parseInt(i64, range.after, 10);
        ranges[range_count].start = start;
        ranges[range_count].end = end;
        ranges[range_count].valid = true;
        range_count += 1;
    }

    var feshCount: usize = 0;
    while (it.next()) |sid| {
        const id = try std.fmt.parseInt(i64, sid, 10);
        for (ranges[0..range_count]) |range| {
            if (id >= range.start and id <= range.end) {
                feshCount += 1;
                break;
            }
        }
    }

    return std.fmt.bufPrint(&buf, "{d}", .{feshCount}) catch "error";
}

pub fn showRanges(ranges: []Range) void {
    for (ranges) |range| {
        if (range.valid) {
            std.debug.print("{d}-{d}\n", .{ range.start, range.end });
        }
    }
}

pub fn sortRanges(ranges: []Range) void {
    std.mem.sort(Range, ranges, {}, lessThanRange);
}

pub fn lessThanRange(_: void, lhs: Range, rhs: Range) bool {
    return lhs.start < rhs.start;
}

pub fn combineRanges(ranges: []Range) void {
    var was_updated = true;
    while (was_updated) {
        was_updated = false;
        sortRanges(ranges[0..ranges.len]);
        for (0..ranges.len - 1) |i| {
            for (i + 1..ranges.len) |j| {
                if (!ranges[i].valid) continue;
                if (!ranges[j].valid) continue;
                if (ranges[i].end + 1 >= ranges[j].start) {
                    ranges[i].end = @max(ranges[i].end, ranges[j].end);
                    ranges[j].valid = false;
                    was_updated = true;
                    break;
                }
            }
        }
    }
}

pub fn part2(input: []const u8) ![]const u8 {
    var ranges: [size]Range = undefined;
    var it = std.mem.splitScalar(u8, input[0 .. input.len - 1], '\n');
    var range_count: usize = 0;
    while (it.next()) |part| {
        if (part.len == 0) break;
        const range = splitOnce(part, '-');
        const start = try std.fmt.parseInt(i64, range.before, 10);
        const end = try std.fmt.parseInt(i64, range.after, 10);
        ranges[range_count].start = start;
        ranges[range_count].end = end;
        ranges[range_count].valid = true;
        range_count += 1;
    }
    combineRanges(ranges[0..range_count]);

    var total: i64 = 0;
    for (ranges[0..range_count]) |range| {
        if (range.valid) total += range.end - range.start + 1;
    }

    return std.fmt.bufPrint(&buf, "{d}", .{total}) catch "error";
}
