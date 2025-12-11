const std = @import("std");

/// Generic FIFO queue backed by a singly-linked list.
///
/// Items are enqueued at the tail and dequeued from the head.
/// Nodes are individually allocated using the provided allocator.
pub fn Queue(comptime Child: type) type {
    return struct {
        const Self = @This();

        /// Internal node storing one queued value.
        const Node = struct {
            data: Child,
            next: ?*Node,
        };

        /// Allocator used for node allocations.
        allocator: std.mem.Allocator,
        /// Pointer to the first node, or null if empty.
        start: ?*Node,
        /// Pointer to the last node, or null if empty.
        end: ?*Node,

        /// Initialize an empty queue that uses `gpa` for allocations.
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .start = null,
                .end = null,
            };
        }

        /// Return true if the queue currently holds no elements.
        pub fn isEmpty(self: *const Self) bool {
            return self.start == null;
        }

        /// Append a value to the back of the queue.
        ///
        /// Allocates a new node; returns an error if allocation fails.
        pub fn enqueue(self: *Self, value: Child) !void {
            const node = try self.allocator.create(Node);
            node.* = .{ .data = value, .next = null };
            if (self.end) |end| end.next = node //
            else self.start = node;
            self.end = node;
        }

        /// Remove and return the value at the front of the queue.
        ///
        /// Returns null if the queue is empty. The removed node is
        /// freed using the allocator.
        pub fn dequeue(self: *Self) ?Child {
            const start = self.start orelse return null;
            defer self.allocator.destroy(start);
            if (start.next) |next|
                self.start = next
            else {
                self.start = null;
                self.end = null;
            }
            return start.data;
        }
    };
}

/// FIFO queue backed by a growable ArrayList.
///
/// Enqueue is O(1) amortized. Dequeue is O(1) amortized with
/// occasional compaction when the consumed prefix grows large.
pub fn ArrayQueue(comptime Child: type) type {
    return struct {
        const Self = @This();

        /// Allocator used for the backing ArrayList.
        gpa: std.mem.Allocator,
        /// Backing storage for queued elements.
        list: std.ArrayList(Child),
        /// Index of the current head element within `list.items`.
        start: usize,

        /// Initialize an empty queue with preallocated capacity.
        pub fn initCapacity(gpa: std.mem.Allocator, capacity: usize) !Self {
            return Self{
                .gpa = gpa,
                .list = try std.ArrayList(Child).initCapacity(gpa, capacity),
                .start = 0,
            };
        }

        /// Free all backing storage. The queue must not be used afterwards.
        pub fn deinit(self: *Self) void {
            self.list.deinit(self.gpa);
        }

        /// Return true if the queue currently holds no elements.
        pub fn isEmpty(self: *const Self) bool {
            return self.start >= self.list.items.len;
        }

        /// Append a value to the back of the queue.
        pub fn enqueue(self: *Self, value: Child) !void {
            try self.list.append(self.gpa, value);
        }

        /// Remove and return the value at the front of the queue.
        ///
        /// Returns null if the queue is empty.
        pub fn dequeue(self: *Self) ?Child {
            if (self.start >= self.list.items.len) return null;

            const value = self.list.items[self.start];
            self.start += 1;

            // Occasionally compact the underlying buffer when the
            // consumed prefix becomes large, to keep indices small
            // and avoid unbounded growth of `start`.
            if (self.start > self.list.items.len / 2 and self.start > 0) {
                const remaining = self.list.items[self.start..];
                @memmove(self.list.items[0..remaining.len], remaining);
                self.list.shrinkRetainingCapacity(remaining.len);
                self.start = 0;
            }

            return value;
        }
    };
}

test "queue" {
    var int_queue = Queue(i32).init(std.testing.allocator);

    try std.testing.expect(int_queue.isEmpty());

    try int_queue.enqueue(25);
    try int_queue.enqueue(50);
    try int_queue.enqueue(75);
    try int_queue.enqueue(100);

    try std.testing.expectEqual(int_queue.dequeue(), 25);
    try std.testing.expectEqual(int_queue.dequeue(), 50);
    try std.testing.expectEqual(int_queue.dequeue(), 75);
    try std.testing.expectEqual(int_queue.dequeue(), 100);
    try std.testing.expectEqual(int_queue.dequeue(), null);

    try std.testing.expect(int_queue.isEmpty());

    try int_queue.enqueue(5);
    try std.testing.expectEqual(int_queue.dequeue(), 5);
    try std.testing.expectEqual(int_queue.dequeue(), null);

    try std.testing.expect(int_queue.isEmpty());
}

test "array queue" {
    var int_queue = try ArrayQueue(i32).initCapacity(std.testing.allocator, 0);
    defer int_queue.deinit();

    try std.testing.expect(int_queue.isEmpty());

    try int_queue.enqueue(25);
    try int_queue.enqueue(50);
    try int_queue.enqueue(75);
    try int_queue.enqueue(100);

    try std.testing.expectEqual(int_queue.dequeue(), 25);
    try std.testing.expectEqual(int_queue.dequeue(), 50);
    try std.testing.expectEqual(int_queue.dequeue(), 75);
    try std.testing.expectEqual(int_queue.dequeue(), 100);
    try std.testing.expectEqual(int_queue.dequeue(), null);

    try std.testing.expect(int_queue.isEmpty());

    try int_queue.enqueue(5);
    try std.testing.expectEqual(int_queue.dequeue(), 5);
    try std.testing.expectEqual(int_queue.dequeue(), null);

    try std.testing.expect(int_queue.isEmpty());
}

test "array queue initCapacity" {
    var int_queue = try ArrayQueue(i32).initCapacity(std.testing.allocator, 8);
    defer int_queue.deinit();

    try std.testing.expect(int_queue.isEmpty());

    try int_queue.enqueue(1);
    try int_queue.enqueue(2);
    try int_queue.enqueue(3);

    try std.testing.expectEqual(int_queue.dequeue(), 1);
    try std.testing.expectEqual(int_queue.dequeue(), 2);
    try std.testing.expectEqual(int_queue.dequeue(), 3);
    try std.testing.expectEqual(int_queue.dequeue(), null);
}
