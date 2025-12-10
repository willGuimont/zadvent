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
        gpa: std.mem.Allocator,
        /// Pointer to the first node, or null if empty.
        start: ?*Node,
        /// Pointer to the last node, or null if empty.
        end: ?*Node,

        /// Initialize an empty queue that uses `gpa` for allocations.
        pub fn init(gpa: std.mem.Allocator) Self {
            return Self{
                .gpa = gpa,
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
            const node = try self.gpa.create(Node);
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
            defer self.gpa.destroy(start);
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
