const std = @import("std");
const lib = @import("lib");
const MQ = lib.min_heap;

var buf: [2048]u8 = undefined;

const Node = struct {
    id: usize,
    priority: i32,
};

fn nodeComparator(context: void, a: Node, b: Node) bool {
    _ = context;
    return a.priority < b.priority;
}

pub fn part1(input: []const u8) ![]const u8 {
    _ = input;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 1. Define the specific MinHeap type for our Node struct and comparator
    const NodeMinHeap = MQ.MinHeap(Node, nodeComparator);

    // 2. Initialize the heap
    var heap = NodeMinHeap.init(allocator, {}); // {} is the context, which is void here
    defer heap.deinit();

    std.debug.print("Min-Heap Operations:\n", .{});

    // 3. Push elements
    try heap.push(Node{ .id = 1, .priority = 50 });
    try heap.push(Node{ .id = 2, .priority = 10 });
    try heap.push(Node{ .id = 3, .priority = 70 });
    try heap.push(Node{ .id = 4, .priority = 5 }); // This should be the minimum

    // 4. Peek
    const peeked = heap.peek();
    if (peeked) |node| {
        std.debug.print("Peek: Min element is Node {d} with priority {d}\n", .{ node.id, node.priority });
    }

    // 5. Pop and demonstrate the Min-Heap property
    std.debug.print("\nPopping elements (should be in ascending order of priority):\n", .{});

    while (heap.pop()) |node| {
        std.debug.print("Popped: Node {d}, Priority {d}\n", .{ node.id, node.priority });
    }

    std.debug.print("\nHeap empty: {any}\n", .{heap.is_empty()});
    return std.fmt.bufPrint(&buf, "not implemented: {d}", .{0}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    _ = input;
    // Your solution here
    return std.fmt.bufPrint(&buf, "not implemented: {d}", .{0}) catch "error";
}
