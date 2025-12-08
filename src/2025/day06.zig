const std = @import("std");

var buf: [2048]u8 = undefined;
const Operator = enum {
    ADD,
    MUL,
};
const size = 1000;
const maxNumLines = 5;
const width = 3753;

pub fn part1(input: []const u8) ![]const u8 {
    var nums: [maxNumLines][size]usize = undefined;
    var ops: [size]Operator = undefined;
    var opIdx: usize = 0;
    var numLines: usize = 0;

    var it = std.mem.splitAny(u8, input, "\n");
    while (it.next()) |line| {
        if (!std.mem.containsAtLeastScalar(u8, line, 1, '*')) {
            var numIt = std.mem.splitAny(u8, line, " ");
            var numIdx: usize = 0;
            while (numIt.next()) |numStr| {
                if (numStr.len == 0) continue;
                nums[numLines][numIdx] = try std.fmt.parseInt(usize, numStr, 10);
                numIdx += 1;
            }
            numLines += 1;
        } else {
            var opIt = std.mem.splitAny(u8, line, " ");
            while (opIt.next()) |opStr| {
                if (opStr.len == 0) continue;
                const op = switch (opStr[0]) {
                    '+' => Operator.ADD,
                    '*' => Operator.MUL,
                    else => unreachable,
                };
                ops[opIdx] = op;
                opIdx += 1;
            }
            break;
        }
    }

    var result: usize = 0;
    for (0..opIdx) |i| {
        switch (ops[i]) {
            Operator.ADD => {
                for (0..numLines) |j| {
                    result += nums[j][i];
                }
            },
            Operator.MUL => {
                var prod: usize = 1;
                for (0..numLines) |j| {
                    prod *= nums[j][i];
                }
                result += prod;
            },
        }
    }

    return std.fmt.bufPrint(&buf, "{d}", .{result}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    var buffer: [maxNumLines][width]u8 = undefined;
    var numLines: usize = 0;
    var maxWidth: usize = 0;
    var it = std.mem.splitAny(u8, input, "\n");
    while (it.next()) |line| {
        for (0..line.len) |i| {
            buffer[numLines][i] = line[i];
            maxWidth = @max(maxWidth, i + 1);
        }
        numLines += 1;
    }
    var result: usize = 0;
    const opLine = buffer[numLines - 2][0..maxWidth];
    var colStart: usize = 0;
    while (colStart < maxWidth) {
        var colWidth = std.mem.indexOfAny(u8, opLine[colStart + 1 ..], "*+");
        if (colWidth == null) {
            colWidth = maxWidth - colStart;
        }
        const colEnd = colStart + colWidth.?;
        var table: [4][maxNumLines]u8 = [_][maxNumLines]u8{[_]u8{' '} ** maxNumLines} ** 4;
        for (0..numLines - 2) |i| {
            const s: []u8 = buffer[i][colStart..colEnd];
            for (0..4) |j| {
                if (j < s.len) {
                    table[j][i] = s[j];
                } else {
                    table[j][i] = ' ';
                }
            }
        }
        
        switch (opLine[colStart]) {
            '*' => {
                var prod: usize = 1;
                for (0..4) |j| {
                    const s = std.mem.trim(u8, &table[j], " \n\t");
                    if (s.len == 0) {
                        continue;
                    }
                    const x = try std.fmt.parseInt(usize, s, 10);
                    prod *= x;
                }
                result += prod;
            },
            '+' => {
                for (0..4) |j| {
                    const s = std.mem.trim(u8, &table[j], " \n");
                    if (s.len == 0) {
                        continue;
                    }
                    const x = try std.fmt.parseInt(usize, s, 10);
                    result += x;
                }
            },
            else => unreachable,
        }
        colStart = colEnd + 1;
    }

    return std.fmt.bufPrint(&buf, "{d}", .{result}) catch "error";
}
