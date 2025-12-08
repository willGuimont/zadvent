const std = @import("std");

var buf: [2048]u8 = undefined;
const size: usize = 143;

pub fn part1(input: []const u8) ![]const u8 {
    var world: [size][size]u8 = undefined;
    var actualSize: usize = 0;

    var it = std.mem.splitAny(u8, input, "\n");
    var lineNum: usize = 0;
    while (it.next()) |line| {
        actualSize = @max(actualSize, line.len);
        @memcpy(world[lineNum][0..line.len], line);
        lineNum += 1;
    }

    const startingPoint = std.mem.indexOf(u8, &world[0], "S").?;
    var currentLine = [_]u8{'.'} ** size;
    currentLine[startingPoint] = '|';

    var numSplits: usize = 0;
    for (1..actualSize) |lineIdx| {
        const worldLine = world[lineIdx];
        var nextLine = [_]u8{'.'} ** size;
        for (0..actualSize) |i| {
            if (currentLine[i] == '|') {
                if (worldLine[i] == '^') {
                    nextLine[i - 1] = '|';
                    nextLine[i + 1] = '|';
                    numSplits += 1;
                } else {
                    nextLine[i] = '|';
                }
            }
        }
        currentLine = nextLine;
    }

    return std.fmt.bufPrint(&buf, "{d}", .{numSplits}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    var world: [size][size]u8 = undefined;
    var actualSize: usize = 0;

    var it = std.mem.splitAny(u8, input, "\n");
    var lineNum: usize = 0;
    while (it.next()) |line| {
        actualSize = @max(actualSize, line.len);
        @memcpy(world[lineNum][0..line.len], line);
        lineNum += 1;
    }

    const startingPoint = std.mem.indexOf(u8, &world[0], "S").?;
    var currentLine = [_]i64{0} ** size;
    currentLine[startingPoint] = 1;

    for (1..actualSize) |lineIdx| {
        const worldLine = world[lineIdx];
        var nextLine = [_]i64{0} ** size;
        for (0..actualSize) |i| {
            const numBeams = currentLine[i];
            if (numBeams > 0) {
                if (worldLine[i] == '^') {
                    nextLine[i - 1] += numBeams;
                    nextLine[i + 1] += numBeams;
                } else {
                    nextLine[i] += numBeams;
                }
            }
        }
        currentLine = nextLine;
    }

    var totalPath: i64 = 0;
    for (0..actualSize) |i| {
        totalPath += currentLine[i];
    }

    return std.fmt.bufPrint(&buf, "{d}", .{totalPath}) catch "error";
}
