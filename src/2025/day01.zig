const std = @import("std");

pub fn part1(input: []const u8) !usize {
    // Parse input and implement Part 1 here.
    // Example: count lines
    var count: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') count += 1;
    }
    return count;
}

pub fn part2(input: []const u8) !usize {
    // Implement Part 2 here. Return any printable type.
    _ = input;
    return 0;
}
