const std = @import("std");

/// Generic undirected weighted edge between two vertices `u` and `v`.
/// The meaning of the vertex indices is defined by the caller.
pub const Edge = struct {
    u: usize,
    v: usize,
    weight: f32,
};
