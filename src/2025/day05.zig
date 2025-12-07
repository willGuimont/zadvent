const std = @import("std");

var buf: [2048]u8 = undefined;
const size = 200;

const Range = struct {
    start: i64,
    end: i64,
    valid: bool,
};

pub fn splitOnce(s: []const u8, c: u8) struct { before: []const u8, after: []const u8 } {
    if (std.mem.indexOfScalar(u8, s, c)) |pos| {
        return .{ .before = s[0..pos], .after = s[pos + 1 ..] };
    }
    return .{ .before = s, .after = "" };
}

pub fn part1(input: []const u8) ![]const u8 {
    var ranges: [size]Range = undefined;
    var it = std.mem.splitAny(u8, input[0 .. input.len - 1], "\n");
    var rangeCount: usize = 0;
    while (it.next()) |part| {
        if (part.len == 0) break;
        const range = splitOnce(part, '-');
        const start = try std.fmt.parseInt(i64, range.before, 10);
        const end = try std.fmt.parseInt(i64, range.after, 10);
        ranges[rangeCount].start = start;
        ranges[rangeCount].end = end;
        ranges[rangeCount].valid = true;
        rangeCount += 1;
    }

    var feshCount: usize = 0;
    while (it.next()) |sid| {
        const id = try std.fmt.parseInt(i64, sid, 10);
        for (ranges[0..rangeCount]) |range| {
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
    var wasUpdated = true;
    while (wasUpdated) {
        wasUpdated = false;
        sortRanges(ranges[0..ranges.len]);
        for (0..ranges.len - 1) |i| {
            for (i + 1..ranges.len) |j| {
                if (!ranges[i].valid) continue;
                if (!ranges[j].valid) continue;
                if (ranges[i].end + 1 >= ranges[j].start) {
                    ranges[i].end = @max(ranges[i].end, ranges[j].end);
                    ranges[j].valid = false;
                    wasUpdated = true;
                    break;
                }
            }
        }
    }
}

pub fn part2(input: []const u8) ![]const u8 {
    var ranges: [size]Range = undefined;
    var it = std.mem.splitAny(u8, input[0 .. input.len - 1], "\n");
    var rangeCount: usize = 0;
    while (it.next()) |part| {
        if (part.len == 0) break;
        const range = splitOnce(part, '-');
        const start = try std.fmt.parseInt(i64, range.before, 10);
        const end = try std.fmt.parseInt(i64, range.after, 10);
        ranges[rangeCount].start = start;
        ranges[rangeCount].end = end;
        ranges[rangeCount].valid = true;
        rangeCount += 1;
    }
    combineRanges(ranges[0..rangeCount]);

    var total: i64 = 0;
    for (ranges[0..rangeCount]) |range| {
        if (range.valid) total += range.end - range.start + 1;
    }

    return std.fmt.bufPrint(&buf, "{d}", .{total}) catch "error";
}
