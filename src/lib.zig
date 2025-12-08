const std = @import("std");

pub const kruskal = @import("lib/kruskal.zig");
pub const min_heap = @import("lib/min_heap.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
