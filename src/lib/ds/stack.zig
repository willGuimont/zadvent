const std = @import("std");

/// Generic LIFO stack backed by a singly-linked list.
///
/// Items are pushed and popped from the top.
/// Nodes are individually allocated using the provided allocator.
pub fn Stack(comptime Child: type) type {
    return struct {
        const Self = @This();

        /// Internal node storing one stacked value.
        const Node = struct {
            data: Child,
            next: ?*Node,
        };

        /// Allocator used for node allocations.
        allocator: std.mem.Allocator,
        /// Pointer to the top node, or null if empty.
        top: ?*Node,

        /// Initialize an empty stack that uses `allocator` for allocations.
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .top = null,
            };
        }

        /// Return true if the stack currently holds no elements.
        pub fn isEmpty(self: *const Self) bool {
            return self.top == null;
        }

        /// Push a value onto the top of the stack.
        ///
        /// Allocates a new node; returns an error if allocation fails.
        pub fn push(self: *Self, value: Child) !void {
            const node = try self.allocator.create(Node);
            node.* = .{ .data = value, .next = self.top };
            self.top = node;
        }

        /// Pop and return the value from the top of the stack.
        ///
        /// Returns null if the stack is empty. The removed node is
        /// freed using the allocator.
        pub fn pop(self: *Self) ?Child {
            const top = self.top orelse return null;
            defer self.allocator.destroy(top);
            self.top = top.next;
            return top.data;
        }
    };
}

/// LIFO stack backed by a growable ArrayList.
///
/// Push and pop are O(1) amortized.
pub fn ArrayStack(comptime Child: type) type {
    return struct {
        const Self = @This();

        /// Allocator used for the backing ArrayList.
        gpa: std.mem.Allocator,
        /// Backing storage for stacked elements.
        list: std.ArrayList(Child),

        /// Initialize an empty stack with preallocated capacity.
        pub fn initCapacity(gpa: std.mem.Allocator, capacity: usize) !Self {
            return Self{
                .gpa = gpa,
                .list = try std.ArrayList(Child).initCapacity(gpa, capacity),
            };
        }

        /// Free all backing storage. The stack must not be used afterwards.
        pub fn deinit(self: *Self) void {
            self.list.deinit(self.gpa);
        }

        /// Return true if the stack currently holds no elements.
        pub fn isEmpty(self: *const Self) bool {
            return self.list.items.len == 0;
        }

        /// Push a value onto the top of the stack.
        pub fn push(self: *Self, value: Child) !void {
            try self.list.append(self.gpa, value);
        }

        /// Pop and return the value from the top of the stack.
        ///
        /// Returns null if the stack is empty.
        pub fn pop(self: *Self) ?Child {
            const len = self.list.items.len;
            if (len == 0) return null;

            const value = self.list.items[len - 1];
            self.list.shrinkRetainingCapacity(len - 1);
            return value;
        }
    };
}

test "stack" {
    var int_stack = Stack(i32).init(std.testing.allocator);

    try std.testing.expect(int_stack.isEmpty());

    try int_stack.push(25);
    try int_stack.push(50);
    try int_stack.push(75);
    try int_stack.push(100);

    try std.testing.expectEqual(int_stack.pop(), 100);
    try std.testing.expectEqual(int_stack.pop(), 75);
    try std.testing.expectEqual(int_stack.pop(), 50);
    try std.testing.expectEqual(int_stack.pop(), 25);
    try std.testing.expectEqual(int_stack.pop(), null);

    try std.testing.expect(int_stack.isEmpty());

    try int_stack.push(5);
    try std.testing.expectEqual(int_stack.pop(), 5);
    try std.testing.expectEqual(int_stack.pop(), null);

    try std.testing.expect(int_stack.isEmpty());
}

test "array stack" {
    var int_stack = try ArrayStack(i32).initCapacity(std.testing.allocator, 0);
    defer int_stack.deinit();

    try std.testing.expect(int_stack.isEmpty());

    try int_stack.push(25);
    try int_stack.push(50);
    try int_stack.push(75);
    try int_stack.push(100);

    try std.testing.expectEqual(int_stack.pop(), 100);
    try std.testing.expectEqual(int_stack.pop(), 75);
    try std.testing.expectEqual(int_stack.pop(), 50);
    try std.testing.expectEqual(int_stack.pop(), 25);
    try std.testing.expectEqual(int_stack.pop(), null);

    try std.testing.expect(int_stack.isEmpty());

    try int_stack.push(5);
    try std.testing.expectEqual(int_stack.pop(), 5);
    try std.testing.expectEqual(int_stack.pop(), null);

    try std.testing.expect(int_stack.isEmpty());
}

test "array stack initCapacity" {
    var int_stack = try ArrayStack(i32).initCapacity(std.testing.allocator, 8);
    defer int_stack.deinit();

    try std.testing.expect(int_stack.isEmpty());

    try int_stack.push(1);
    try int_stack.push(2);
    try int_stack.push(3);

    try std.testing.expectEqual(int_stack.pop(), 3);
    try std.testing.expectEqual(int_stack.pop(), 2);
    try std.testing.expectEqual(int_stack.pop(), 1);
    try std.testing.expectEqual(int_stack.pop(), null);
}
