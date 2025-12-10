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

/// Convert the low N bits of an integer value into a fixed-size buffer
/// of ASCII '0'/'1' characters, where N is the bit-width of the output
/// integer type `OutBits` (e.g. `u8` → 8 bits, `u10` → 10 bits).
///
/// The returned slice is ordered from most-significant to
/// least-significant bit of the masked low-N-bit value.
///
/// This is useful for lightweight debugging/printing of bitfields
/// without allocating.
pub fn toBits(comptime OutBits: type, comptime T: type, value: T) [@bitSizeOf(OutBits)]u8 {
    const N: usize = @bitSizeOf(OutBits);
    comptime std.debug.assert(N > 0 and N <= 64);

    var out: [N]u8 = undefined;

    // Work in u64 and mask to low N bits.
    const mask: u64 = if (N == 64) ~@as(u64, 0) else (@as(u64, 1) << @intCast(N)) - 1;
    const masked: u64 = @as(u64, @intCast(value)) & mask;

    var i: usize = 0;
    while (i < N) : (i += 1) {
        const i_signed: i32 = @intCast(i);
        const shift_signed: i32 = @as(i32, @intCast(N)) - 1 - i_signed;
        const shift: u6 = @intCast(shift_signed);
        const bit = (masked >> shift) & 1;
        out[i] = if (bit == 1) '1' else '0';
    }

    return out;
}

/// Convenience wrapper that returns exactly 8 bits (equivalent to
/// `toBits(u8, T, value)`).
fn to8Bits(comptime T: type, value: T) [8]u8 {
    return toBits(u8, T, value);
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

test "to8Bits encodes low 8 bits" {
    const bits_zero = to8Bits(u8, 0);
    try std.testing.expectEqualStrings("00000000", bits_zero[0..]);

    const bits_one = to8Bits(u8, 1);
    try std.testing.expectEqualStrings("00000001", bits_one[0..]);

    const bits_pattern = to8Bits(u8, 0b10101010);
    try std.testing.expectEqualStrings("10101010", bits_pattern[0..]);
}

test "toBits encodes arbitrary bit widths" {
    // 4 bits from 0b1101 → "1101"
    const bits4 = toBits(u4, u8, 0b01101);
    try std.testing.expectEqualStrings("1101", bits4[0..]);

    // 10 bits from 0b1111110001 → "1111110001"
    const bits10 = toBits(u10, u16, 0b1111110001);
    try std.testing.expectEqualStrings("1111110001", bits10[0..]);
}
