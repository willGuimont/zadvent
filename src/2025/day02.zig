const std = @import("std");
const splitOnce = @import("lib").str_utils.splitOnce;

var buf: [2048]u8 = undefined;

pub fn part1(input: []const u8) ![]const u8 {
    var it = std.mem.splitAny(u8, input[0 .. input.len - 1], ",");
    var invalid_sum: u64 = 0;
    while (it.next()) |s| {
        if (s.len == 0) continue;

        const pos = splitOnce(s, '-');
        const start = try std.fmt.parseInt(u64, pos.before, 10);
        const end = try std.fmt.parseInt(u64, pos.after, 10);

        var id: u64 = start;
        while (id <= end) : (id += 1) {
            const asText = std.fmt.bufPrint(&buf, "{d}", .{id}) catch return error.InvalidInput;
            if (@mod(asText.len, 2) == 0) {
                const half = @divTrunc(asText.len, 2);
                if (std.mem.eql(u8, buf[0..half], buf[half..asText.len])) {
                    invalid_sum += id;
                }
            }
        }
    }
    return std.fmt.bufPrint(&buf, "{d}", .{invalid_sum}) catch "error";
}

pub fn areChunksEqual(s: []const u8, n: usize) bool {
    if (n >= s.len or @mod(s.len, n) != 0) {
        return false;
    }
    const first = s[0..n];
    var i = n;
    while (i + n <= s.len) : (i += n) {
        const chunk = s[i .. i + n];
        if (!std.mem.eql(u8, first, chunk)) {
            return false;
        }
    }
    return true;
}

pub fn isRepeatedPattern(s: []const u8) bool {
    var n: usize = 1;
    while (n <= s.len / 2) : (n += 1) {
        if (areChunksEqual(s, n)) {
            return true;
        }
    }
    return false;
}

pub fn part2(input: []const u8) ![]const u8 {
    var it = std.mem.splitAny(u8, input[0 .. input.len - 1], ",");
    var invalid_sum: u64 = 0;
    while (it.next()) |s| {
        if (s.len == 0) continue;

        const pos = splitOnce(s, '-');
        const start = try std.fmt.parseInt(u64, pos.before, 10);
        const end = try std.fmt.parseInt(u64, pos.after, 10);

        var id: u64 = start;
        while (id <= end) : (id += 1) {
            const asText = std.fmt.bufPrint(&buf, "{d}", .{id}) catch return error.InvalidInput;
            if (isRepeatedPattern(asText)) {
                invalid_sum += id;
            }
        }
    }
    return std.fmt.bufPrint(&buf, "{d}", .{invalid_sum}) catch "error";
}
