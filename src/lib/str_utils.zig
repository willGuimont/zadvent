const std = @import("std");

/// Splits a string into two parts at the first occurrence of a separator character.
/// Returns a struct containing the substring before and after the separator.
/// If the separator is not found, returns the entire string as `before` and an empty string as `after`.
///
/// Parameters:
///   - s: The string to split
///   - c: The separator character to split on
///
/// Returns:
///   A struct with two fields:
///   - before: substring before the first occurrence of the separator
///   - after: substring after the first occurrence of the separator
pub fn splitOnce(s: []const u8, c: u8) struct { before: []const u8, after: []const u8 } {
    if (std.mem.indexOfScalar(u8, s, c)) |pos| {
        return .{ .before = s[0..pos], .after = s[pos + 1 ..] };
    }
    return .{ .before = s, .after = "" };
}

test "splitOnce on ," {
    const input = "hello,world";
    const result = splitOnce(input, ',');
    try std.testing.expectEqualStrings("hello", result.before);
    try std.testing.expectEqualStrings("world", result.after);
}

test "splitOnce if separator is not found" {
    const input = "hello";
    const result = splitOnce(input, ',');
    try std.testing.expectEqualStrings("hello", result.before);
    try std.testing.expectEqualStrings("", result.after);
}

test "splitOnce if separator is at the beginning" {
    const input = ",world";
    const result = splitOnce(input, ',');
    try std.testing.expectEqualStrings("", result.before);
    try std.testing.expectEqualStrings("world", result.after);
}

test "splitOnce if separator is at the end" {
    const input = "hello,";
    const result = splitOnce(input, ',');
    try std.testing.expectEqualStrings("hello", result.before);
    try std.testing.expectEqualStrings("", result.after);
}
