const std = @import("std");

/// Basic 2D vector used by collision helpers.
pub const Vec2 = struct {
    x: f32,
    y: f32,
};

/// Basic 3D vector used by collision helpers.
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

/// Axis-aligned bounding box in 2D, defined by minimum and maximum corner.
///
/// Invariants:
/// - `min.x <= max.x`
/// - `min.y <= max.y`
pub const Aabb2D = struct {
    min: Vec2,
    max: Vec2,
};

/// Circle in 2D, represented by center and radius.
pub const Circle = struct {
    center: Vec2,
    radius: f32,
};

/// Sphere in 3D, represented by center and radius.
pub const Sphere = struct {
    center: Vec3,
    radius: f32,
};

/// 2D edge with integer coordinates, useful for grid-based geometry.
pub const Edge = struct {
    x1: i64,
    y1: i64,
    x2: i64,
    y2: i64,
};

/// Simple polygon represented by a list of edges.
///
/// The caller is responsible for ensuring the edges form a sensible
/// polygon (for example, a closed loop). This type is intentionally
/// lightweight and does not enforce topological constraints.
pub const Polygon = struct {
    edges: []const Edge,

    /// Test whether any edge's bounding box overlaps the given
    /// axis-aligned rectangle.
    ///
    /// This mirrors the logic used in AoC day09's Go solution:
    /// it checks strict overlap of the 1D projections on both axes
    /// using integer coordinates.
    pub fn intersectsAabb(self: Polygon, min_x: i64, min_y: i64, max_x: i64, max_y: i64) bool {
        for (self.edges) |e| {
            const i_min_x = @min(e.x1, e.x2);
            const i_max_x = @max(e.x1, e.x2);
            const i_min_y = @min(e.y1, e.y2);
            const i_max_y = @max(e.y1, e.y2);

            if (min_x < i_max_x and max_x > i_min_x and
                min_y < i_max_y and max_y > i_min_y)
            {
                return true;
            }
        }
        return false;
    }

    /// Check whether an integer point lies inside this polygon.
    ///
    /// The check is inclusive of the boundary: if the point lies exactly
    /// on one of the edges, this returns `true`.
    pub fn containsPoint(self: Polygon, x: i64, y: i64) bool {
        // First, check if the point lies exactly on any edge.
        for (self.edges) |e| {
            const min_x = @min(e.x1, e.x2);
            const max_x = @max(e.x1, e.x2);
            const min_y = @min(e.y1, e.y2);
            const max_y = @max(e.y1, e.y2);

            if (x < min_x or x > max_x or y < min_y or y > max_y) continue;

            const dx = e.x2 - e.x1;
            const dy = e.y2 - e.y1;
            const cross = dx * (y - e.y1) - dy * (x - e.x1);
            if (cross == 0) {
                return true;
            }
        }

        // Standard even-odd (ray casting) test to the +X direction.
        var inside = false;
        const py = y;
        const fx = @as(f64, @floatFromInt(x));

        for (self.edges) |e| {
            const y1 = e.y1;
            const y2 = e.y2;

            const above1 = y1 > py;
            const above2 = y2 > py;
            if (above1 == above2) continue; // Edge does not cross the horizontal ray.

            const dy = y2 - y1;
            if (dy == 0) continue; // Horizontal edge already skipped by above check.

            const t = @as(f64, @floatFromInt(py - y1)) / @as(f64, @floatFromInt(dy));
            const fx1 = @as(f64, @floatFromInt(e.x1));
            const fx2 = @as(f64, @floatFromInt(e.x2));
            const x_intersect = fx1 + (fx2 - fx1) * t;

            if (fx < x_intersect) {
                inside = !inside;
            }
        }

        return inside;
    }
};

/// Manhattan distance between two 2D points using their coordinates.
///
/// This assumes integer-like coordinates encoded as `f32` (as used by
/// the rest of this module) and returns the L1 distance as `f32`.
pub fn manhattanDistance2D(a: Vec2, b: Vec2) f32 {
    const dx = @abs(a.x - b.x);
    const dy = @abs(a.y - b.y);
    return dx + dy;
}

/// Compute squared distance between two 2D points.
///
/// Using squared distance avoids a `sqrt` in callers that only need
/// comparisons (for example, circle/sphere overlap tests).
pub fn distanceSquared2D(a: Vec2, b: Vec2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return dx * dx + dy * dy;
}

/// Compute squared distance between two 3D points.
pub fn distanceSquared3D(a: Vec3, b: Vec3) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const dz = a.z - b.z;
    return dx * dx + dy * dy + dz * dz;
}

/// Test whether two 2D AABBs overlap (including touching edges).
///
/// Returns `true` if the projections along both axes intersect:
/// - `[a.min.x, a.max.x]` overlaps `[b.min.x, b.max.x]`
/// - `[a.min.y, a.max.y]` overlaps `[b.min.y, b.max.y]`
pub fn aabbOverlap2D(a: Aabb2D, b: Aabb2D) bool {
    const no_x = a.max.x < b.min.x or b.max.x < a.min.x;
    const no_y = a.max.y < b.min.y or b.max.y < a.min.y;
    return !(no_x or no_y);
}

/// Test whether a point lies inside (or on the boundary of) a 2D AABB.
pub fn aabbContainsPoint2D(box: Aabb2D, p: Vec2) bool {
    return p.x >= box.min.x and p.x <= box.max.x and
        p.y >= box.min.y and p.y <= box.max.y;
}

/// Test whether a 2D line segment intersects a 2D AABB.
///
/// The check is inclusive:
/// - Returns `true` if either endpoint lies inside the box.
/// - Returns `true` if the segment touches or crosses any edge.
pub fn lineSegmentIntersectsAabb2D(p1: Vec2, p2: Vec2, box: Aabb2D) bool {
    // Trivial accept: one of the endpoints is inside the box.
    if (aabbContainsPoint2D(box, p1) or aabbContainsPoint2D(box, p2)) {
        return true;
    }

    // Check intersection with each of the four box edges.
    const bl = Vec2{ .x = box.min.x, .y = box.min.y }; // bottom-left
    const br = Vec2{ .x = box.max.x, .y = box.min.y }; // bottom-right
    const tr = Vec2{ .x = box.max.x, .y = box.max.y }; // top-right
    const tl = Vec2{ .x = box.min.x, .y = box.max.y }; // top-left

    if (lineSegmentsIntersect2D(p1, p2, bl, br)) return true;
    if (lineSegmentsIntersect2D(p1, p2, br, tr)) return true;
    if (lineSegmentsIntersect2D(p1, p2, tr, tl)) return true;
    if (lineSegmentsIntersect2D(p1, p2, tl, bl)) return true;

    return false;
}

/// Test whether two 2D line segments intersect.
///
/// Segments are defined by their endpoints `[p1, p2]` and `[q1, q2]`.
/// The test is inclusive: touching at endpoints or overlapping
/// collinear segments both count as an intersection.
pub fn lineSegmentsIntersect2D(p1: Vec2, p2: Vec2, q1: Vec2, q2: Vec2) bool {
    const o1 = orientation2D(p1, p2, q1);
    const o2 = orientation2D(p1, p2, q2);
    const o3 = orientation2D(q1, q2, p1);
    const o4 = orientation2D(q1, q2, p2);

    // General case
    if (o1 != o2 and o3 != o4) return true;

    // Special cases: collinear and on-segment
    if (o1 == 0 and onSegment2D(p1, q1, p2)) return true;
    if (o2 == 0 and onSegment2D(p1, q2, p2)) return true;
    if (o3 == 0 and onSegment2D(q1, p1, q2)) return true;
    if (o4 == 0 and onSegment2D(q1, p2, q2)) return true;

    return false;
}

/// Compute the intersection point of two 2D line segments, if any.
///
/// Returns `null` if the segments do not intersect or are parallel.
/// For overlapping collinear segments, this returns one of the
/// intersection points (not all of them).
pub fn lineSegmentsIntersectionPoint2D(p1: Vec2, p2: Vec2, q1: Vec2, q2: Vec2) ?Vec2 {
    const r = Vec2{ .x = p2.x - p1.x, .y = p2.y - p1.y };
    const s = Vec2{ .x = q2.x - q1.x, .y = q2.y - q1.y };

    const rxs = cross2D(r, s);
    const q_p = Vec2{ .x = q1.x - p1.x, .y = q1.y - p1.y };

    if (rxs == 0) {
        // Parallel or collinear; do not try to enumerate all overlaps here.
        return null;
    }

    const t = cross2D(q_p, s) / rxs;
    const u = cross2D(q_p, r) / rxs;

    if (t < 0 or t > 1 or u < 0 or u > 1) return null;

    return Vec2{
        .x = p1.x + t * r.x,
        .y = p1.y + t * r.y,
    };
}

/// Test whether a 2D circle contains a point (including boundary).
pub fn circleContainsPoint(circle: Circle, p: Vec2) bool {
    const dist2 = distanceSquared2D(circle.center, p);
    const r2 = circle.radius * circle.radius;
    return dist2 <= r2;
}

/// Test whether two 2D circles overlap (including touching).
pub fn circlesOverlap(a: Circle, b: Circle) bool {
    const dist2 = distanceSquared2D(a.center, b.center);
    const r = a.radius + b.radius;
    const r2 = r * r;
    return dist2 <= r2;
}

/// Test whether a 3D sphere contains a point (including boundary).
pub fn sphereContainsPoint(sphere: Sphere, p: Vec3) bool {
    const dist2 = distanceSquared3D(sphere.center, p);
    const r2 = sphere.radius * sphere.radius;
    return dist2 <= r2;
}

/// Test whether two 3D spheres overlap (including touching).
pub fn spheresOverlap(a: Sphere, b: Sphere) bool {
    const dist2 = distanceSquared3D(a.center, b.center);
    const r = a.radius + b.radius;
    const r2 = r * r;
    return dist2 <= r2;
}

/// Signed 2D cross product of vectors (a.x, a.y) and (b.x, b.y).
/// Positive if `b` is to the left of `a`, negative if to the right,
/// and zero if collinear.
pub fn cross2D(a: Vec2, b: Vec2) f32 {
    return a.x * b.y - a.y * b.x;
}

/// Orientation helper used by segment intersection tests.
///
/// Returns:
/// - `> 0` if (p, q, r) make a counter-clockwise turn
/// - `< 0` if clockwise
/// - `0` if collinear
fn orientation2D(p: Vec2, q: Vec2, r: Vec2) i32 {
    const val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
    if (val > 0) return 1;
    if (val < 0) return -1;
    return 0;
}

/// Check whether point `q` lies on the segment `[p, r]` assuming collinearity.
fn onSegment2D(p: Vec2, q: Vec2, r: Vec2) bool {
    return q.x >= @min(p.x, r.x) and q.x <= @max(p.x, r.x) and
        q.y >= @min(p.y, r.y) and q.y <= @max(p.y, r.y);
}

test "collisions basic compile" {
    // Simple sanity checks to ensure the API is usable.
    const box_a = Aabb2D{
        .min = Vec2{ .x = 0, .y = 0 },
        .max = Vec2{ .x = 1, .y = 1 },
    };
    const box_b = Aabb2D{
        .min = Vec2{ .x = 0.5, .y = 0.5 },
        .max = Vec2{ .x = 2, .y = 2 },
    };
    std.debug.assert(aabbOverlap2D(box_a, box_b));

    const p = Vec3{ .x = 0, .y = 0, .z = 0 };
    const s = Sphere{ .center = p, .radius = 1.0 };
    std.debug.assert(sphereContainsPoint(s, p));

    const box_line = Aabb2D{
        .min = Vec2{ .x = -1, .y = -1 },
        .max = Vec2{ .x = 1, .y = 1 },
    };
    const lp1 = Vec2{ .x = -2, .y = 0 };
    const lp2 = Vec2{ .x = 2, .y = 0 };
    std.debug.assert(lineSegmentIntersectsAabb2D(lp1, lp2, box_line));

    const lp3 = Vec2{ .x = -2, .y = 2 };
    const lp4 = Vec2{ .x = 2, .y = 2 };
    std.debug.assert(!lineSegmentIntersectsAabb2D(lp3, lp4, box_line));
}

test "polygon basic" {
    // Square from (0,0) to (10,10).
    const edges = [_]Edge{
        Edge{ .x1 = 0, .y1 = 0, .x2 = 10, .y2 = 0 },
        Edge{ .x1 = 10, .y1 = 0, .x2 = 10, .y2 = 10 },
        Edge{ .x1 = 10, .y1 = 10, .x2 = 0, .y2 = 10 },
        Edge{ .x1 = 0, .y1 = 10, .x2 = 0, .y2 = 0 },
    };

    const poly = Polygon{ .edges = &edges };

    // Inside point.
    std.debug.assert(poly.containsPoint(5, 5));

    // On-edge point.
    std.debug.assert(poly.containsPoint(0, 5));

    // Outside point.
    std.debug.assert(!poly.containsPoint(11, 5));

    // AABB fully inside polygon (no edge overlap) should NOT intersect
    // according to the edge-bounding-box semantics used here.
    std.debug.assert(!poly.intersectsAabb(2, 2, 8, 8));

    // AABB that crosses the left edge of the square should intersect.
    std.debug.assert(poly.intersectsAabb(-2, 2, 5, 8));

    // AABB completely outside polygon.
    std.debug.assert(!poly.intersectsAabb(20, 20, 30, 30));
}
