const std = @import("std");

var buf: [2048]u8 = undefined;

pub fn combine(x: i64, y: i64) !i64 {
    const concat = std.fmt.bufPrint(&buf, "{d}{d}", .{ x, y }) catch "error";
    return std.fmt.parseInt(i64, concat, 10);
}

pub fn findBestJolts(cells: []const i64, comptime n: i64) !i64 {
    var state: [n + 1][101]i64 = [_][101]i64{[_]i64{0} ** 101} ** (n + 1);
    for (1..n + 1) |chosen| {
        for (1..cells.len + 1) |upTo| {
            if (chosen > upTo) continue;
            const skip = state[chosen][upTo - 1];
            const taken = try combine(state[chosen - 1][upTo - 1], cells[upTo - 1]);
            state[chosen][upTo] = @max(skip, taken);
        }
    }
    return state[n][cells.len];
}

pub fn solve(input: []const u8, comptime n: usize) ![]const u8 {
    var it = std.mem.splitScalar(u8, input[0 .. input.len - 1], '\n');
    var total_jolts: i64 = 0;
    var digits: [100]i64 = undefined;
    while (it.next()) |s| {
        for (s, 0..) |c, i| {
            if (c < '0' or c > '9') return error.InvalidDigit;
            digits[i] = @intCast(c - '0');
        }
        total_jolts += try findBestJolts(digits[0..s.len], n);
    }
    return std.fmt.bufPrint(&buf, "{d}", .{total_jolts}) catch "error";
}

pub fn part1(input: []const u8) ![]const u8 {
    return try solve(input, 2);
}

pub fn part2(input: []const u8) ![]const u8 {
    return try solve(input, 12);
}
