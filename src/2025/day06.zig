const std = @import("std");

var buf: [2048]u8 = undefined;
const Operator = enum {
    ADD,
    MUL,
};
const size = 1000;
const max_num_lines = 5;
const width = 3753;

pub fn part1(input: []const u8) ![]const u8 {
    var nums: [max_num_lines][size]usize = undefined;
    var ops: [size]Operator = undefined;
    var opidx: usize = 0;
    var numLines: usize = 0;

    var it = std.mem.splitAny(u8, input, "\n");
    while (it.next()) |line| {
        if (!std.mem.containsAtLeastScalar(u8, line, 1, '*')) {
            var numit = std.mem.splitAny(u8, line, " ");
            var numidx: usize = 0;
            while (numit.next()) |numStr| {
                if (numStr.len == 0) continue;
                nums[numLines][numidx] = try std.fmt.parseInt(usize, numStr, 10);
                numidx += 1;
            }
            numLines += 1;
        } else {
            var opit = std.mem.splitAny(u8, line, " ");
            while (opit.next()) |opStr| {
                if (opStr.len == 0) continue;
                const op = switch (opStr[0]) {
                    '+' => Operator.ADD,
                    '*' => Operator.MUL,
                    else => unreachable,
                };
                ops[opidx] = op;
                opidx += 1;
            }
            break;
        }
    }

    var result: usize = 0;
    for (0..opidx) |i| {
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
    var buffer: [max_num_lines][width]u8 = undefined;
    var num_lines: usize = 0;
    var max_width: usize = 0;
    var it = std.mem.splitAny(u8, input, "\n");
    while (it.next()) |line| {
        for (0..line.len) |i| {
            buffer[num_lines][i] = line[i];
            max_width = @max(max_width, i + 1);
        }
        num_lines += 1;
    }
    var result: usize = 0;
    const op_line = buffer[num_lines - 2][0..max_width];
    var col_start: usize = 0;
    while (col_start < max_width) {
        var col_width = std.mem.indexOfAny(u8, op_line[col_start + 1 ..], "*+");
        if (col_width == null) {
            col_width = max_width - col_start;
        }
        const col_end = col_start + col_width.?;
        var table: [4][max_num_lines]u8 = [_][max_num_lines]u8{[_]u8{' '} ** max_num_lines} ** 4;
        for (0..num_lines - 2) |i| {
            const s: []u8 = buffer[i][col_start..col_end];
            for (0..4) |j| {
                if (j < s.len) {
                    table[j][i] = s[j];
                } else {
                    table[j][i] = ' ';
                }
            }
        }
        
        switch (op_line[col_start]) {
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
        col_start = col_end + 1;
    }

    return std.fmt.bufPrint(&buf, "{d}", .{result}) catch "error";
}
