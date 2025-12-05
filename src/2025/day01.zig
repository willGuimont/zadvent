const std = @import("std");

var buf1: [2048]u8 = undefined;

pub fn part1(input: []const u8) ![]const u8 {
    var count: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') count += 1;
    }
    return std.fmt.bufPrint(&buf1, "{d}", .{count}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    _ = input;
    return "a";
}
