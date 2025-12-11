const std = @import("std");
const Allocator = std.mem.Allocator;

/// Create a min-heap type over `T` using a comparator with signature
/// `fn (Context, T, T) bool` that returns true when the first element
/// should come before the second.
pub fn MinHeapWithContext(comptime T: type, comptime Context: type, comptime lessThanfn: fn (Context, T, T) bool) type {
    return struct {
        const Self = @This();
        items: std.ArrayListUnmanaged(T),
        allocator: Allocator,
        context: Context,

        /// Initialize an empty heap with the provided allocator and comparator context.
        pub fn init(allocator: Allocator, context_arg: Context) Self {
            return Self{
                .items = .{},
                .allocator = allocator,
                .context = context_arg,
            };
        }

        /// Free any storage owned by the heap.
        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        /// Number of elements currently stored.
        pub fn len(self: Self) usize {
            return self.items.items.len;
        }

        /// Whether the heap holds no elements.
        pub fn is_empty(self: Self) bool {
            return self.len() == 0;
        }

        /// View the minimum element without removing it.
        pub fn peek(self: Self) ?*const T {
            if (self.is_empty()) return null;
            return &self.items.items[0];
        }

        /// Insert a new element and restore heap order by sifting upward.
        pub fn push(self: *Self, item: T) !void {
            try self.items.append(self.allocator, item);
            // New element is at the end; move it up until the heap property holds.
            self.sift_up(self.len() - 1);
        }

        /// Remove and return the minimum element, restoring heap order by sifting downward.
        pub fn pop(self: *Self) ?T {
            if (self.is_empty()) return null;

            const last_index = self.len() - 1;
            const min_element = self.items.items[0];

            // Move last element to the root position and drop the duplicate tail.
            self.items.items[0] = self.items.items[last_index];
            _ = self.items.pop();

            // Re-establish heap property starting from the root.
            if (!self.is_empty()) {
                self.sift_down(0);
            }

            return min_element;
        }

        /// Bubble an element toward the root while it is smaller than its parent.
        fn sift_up(self: *Self, index: usize) void {
            var idx = index;
            while (idx > 0) {
                const parent = (idx - 1) / 2;
                // If child < parent, swap and continue up the tree.
                if (lessThanfn(self.context, self.items.items[idx], self.items.items[parent])) {
                    std.mem.swap(T, &self.items.items[idx], &self.items.items[parent]);
                    idx = parent;
                } else {
                    break;
                }
            }
        }

        /// Push an element downward, swapping with the smallest child until the heap property holds.
        fn sift_down(self: *Self, index: usize) void {
            var idx = index;
            const count = self.len();
            while (true) {
                const left = 2 * idx + 1;
                const right = 2 * idx + 2;
                var smallest = idx;

                // Pick the smallest child to potentially swap with.
                if (left < count and lessThanfn(self.context, self.items.items[left], self.items.items[smallest])) {
                    smallest = left;
                }
                if (right < count and lessThanfn(self.context, self.items.items[right], self.items.items[smallest])) {
                    smallest = right;
                }

                if (smallest != idx) {
                    // Swap down and continue from the child position.
                    std.mem.swap(T, &self.items.items[idx], &self.items.items[smallest]);
                    idx = smallest;
                } else {
                    break;
                }
            }
        }
    };
}

/// Convenience wrapper for a void context comparator.
pub fn MinHeap(comptime U: type, comptime lessThanFn: fn (void, U, U) bool) type {
    return MinHeapWithContext(U, void, lessThanFn);
}

// Unit tests
test "MinHeap push and pop ordering" {
    const allocator = std.testing.allocator;

    const Cmp = fn (void, i32, i32) bool;
    const cmp: Cmp = struct {
        fn f(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.f;

    var heap = MinHeap(i32, cmp).init(allocator, {});
    defer heap.deinit();

    try heap.push(5);
    try heap.push(3);
    try heap.push(7);
    try heap.push(1);

    try std.testing.expectEqual(heap.pop(), 1);
    try std.testing.expectEqual(heap.pop(), 3);
    try std.testing.expectEqual(heap.pop(), 5);
    try std.testing.expectEqual(heap.pop(), 7);
    try std.testing.expectEqual(heap.pop(), null);
}

test "MinHeap peek keeps element" {
    const allocator = std.testing.allocator;

    const Cmp = fn (void, i32, i32) bool;
    const cmp: Cmp = struct {
        fn f(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.f;

    var heap = MinHeap(i32, cmp).init(allocator, {});
    defer heap.deinit();

    try heap.push(5);
    try heap.push(3);

    const top = heap.peek();
    try std.testing.expect(top != null);
    try std.testing.expectEqual(top.?.*, 3);

    try std.testing.expectEqual(heap.pop(), 3);
}

test "MinHeap is_empty tracking" {
    const allocator = std.testing.allocator;

    const Cmp = fn (void, i32, i32) bool;
    const cmp: Cmp = struct {
        fn f(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.f;

    var heap = MinHeap(i32, cmp).init(allocator, {});
    defer heap.deinit();

    try std.testing.expect(heap.is_empty());
    try heap.push(42);
    try std.testing.expect(!heap.is_empty());
    _ = heap.pop();
    try std.testing.expect(heap.is_empty());
}
