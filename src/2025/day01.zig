const std = @import("std");

var buf: [2048]u8 = undefined;

pub fn part1(input: []const u8) ![]const u8 {
    var dial: i32 = 50;
    var num_zeros: i32 = 0;
    var it = std.mem.splitAny(u8, input, "\n");
    while (it.next()) |s| {
        if (s.len == 0) continue;
        const sign: i32 = switch (s[0]) {
            'L' => -1,
            'R' => 1,
            else => return error.InvalidInput,
        };
        const n = try std.fmt.parseInt(i32, s[1..], 10);
        dial += n * sign;
        dial = @mod(dial, 100);
        if (dial == 0) {
            num_zeros += 1;
        }
    }
    return std.fmt.bufPrint(&buf, "{d}", .{num_zeros}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    var dial: i32 = 50;
    var num_zeros: i32 = 0;
    var it = std.mem.splitAny(u8, input, "\n");
    while (it.next()) |s| {
        if (s.len == 0) continue;
        const sign: i32 = switch (s[0]) {
            'L' => -1,
            'R' => 1,
            else => return error.InvalidInput,
        };
        const n = try std.fmt.parseInt(i32, s[1..], 10);
        dial += sign * n;
        num_zeros += @intCast(@abs(@divFloor(dial, 100)));
        dial = @mod(dial, 100);
    }
    return std.fmt.bufPrint(&buf, "{d}", .{num_zeros}) catch "error";
}
