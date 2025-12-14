const std = @import("std");

/// Utilities for working with small dense matrices and linear systems.
///
/// This module currently provides:
/// - Gaussian elimination over `f64` (real numbers)
/// - Gaussian elimination over `i64` with integer-only arithmetic
/// - Gaussian elimination over GF(2) for up to 64 variables using `u64` bit rows
pub const GaussF64Error = error{SingularMatrix};
pub const GaussMod2Error = error{NoSolution};
pub const GaussIntError = error{ SingularMatrix, NonIntegralSolution };

/// Solve a linear system A * x = b using Gaussian elimination with
/// partial pivoting on an explicit row-major dense matrix.
///
/// Parameters:
///   rows: number of rows in A
///   cols: number of columns in A (and size of x)
///   a:    slice of length rows * cols, row-major (modified in-place)
///   b:    slice of length rows (RHS, modified in-place)
///   x:    slice of length cols (output solution, fully overwritten)
///
/// Performance note: this routine performs elimination directly on `a`
/// and `b` to avoid extra allocations and copies. If you need to
/// preserve the original matrix and RHS, make explicit copies before
/// calling.
///
/// On success, `x` contains one solution. On singular matrices (no
/// unique solution), returns `error.SingularMatrix`.
pub fn gaussianEliminationF64(
    rows: usize,
    cols: usize,
    a: []f64,
    b: []f64,
    x: []f64,
) GaussF64Error!void {
    gaussianEliminationF64Eliminate(rows, cols, a, b);
    try gaussianEliminationF64ExtractSolution(rows, cols, a, b, x);
}

/// Perform in-place Gaussian elimination with partial pivoting on the
/// real-valued system A * x = b. The matrix `a` and RHS `b` are
/// transformed to (approximate) reduced row echelon form. This
/// function does not check for inconsistency; call
/// `gaussianEliminationF64ExtractSolution` afterwards to detect
/// singular systems and read out a solution vector.
pub fn gaussianEliminationF64Eliminate(
    rows: usize,
    cols: usize,
    a: []f64,
    b: []f64,
) void {
    std.debug.assert(a.len >= rows * cols);
    std.debug.assert(b.len >= rows);

    const eps: f64 = 1e-12;

    // Forward elimination with partial pivoting.
    var r: usize = 0;
    var c: usize = 0;
    while (r < rows and c < cols) : (c += 1) {
        // Find pivot row with largest absolute value in column c.
        var pivot_row: ?usize = null;
        var best_val: f64 = 0.0;
        var i: usize = r;
        while (i < rows) : (i += 1) {
            const val = @abs(a[i * cols + c]);
            if (val > best_val + eps) {
                best_val = val;
                pivot_row = i;
            }
        }

        if (pivot_row == null) {
            // Column is effectively zero, move to next column (free variable).
            continue;
        }

        const pr = pivot_row.?;
        // Swap current row r with pivot row pr.
        if (pr != r) {
            var j: usize = c;
            while (j < cols) : (j += 1) {
                const idx1 = r * cols + j;
                const idx2 = pr * cols + j;
                const tmp = a[idx1];
                a[idx1] = a[idx2];
                a[idx2] = tmp;
            }
            const tmp_b = b[r];
            b[r] = b[pr];
            b[pr] = tmp_b;
        }

        const pivot = a[r * cols + c];
        if (@abs(pivot) <= eps) {
            // Treat as zero; no useful pivot.
            continue;
        }

        // Normalize pivot row.
        var j2: usize = c + 1;
        while (j2 < cols) : (j2 += 1) {
            a[r * cols + j2] /= pivot;
        }
        b[r] /= pivot;
        a[r * cols + c] = 1.0;

        // Eliminate this column from other rows.
        var row2: usize = 0;
        while (row2 < rows) : (row2 += 1) {
            if (row2 == r) continue;
            const factor = a[row2 * cols + c];
            if (@abs(factor) <= eps) continue;
            a[row2 * cols + c] = 0.0;
            var j3: usize = c + 1;
            while (j3 < cols) : (j3 += 1) {
                a[row2 * cols + j3] -= factor * a[r * cols + j3];
            }
            b[row2] -= factor * b[r];
        }

        r += 1;
    }
}

/// After `gaussianEliminationF64Eliminate` has produced (approximate)
/// reduced row echelon form in `a` and `b`, extract one solution
/// vector into `x`. Non-pivot columns are treated as free variables
/// and set to 0. Returns `error.SingularMatrix` if the system is
/// inconsistent.
pub fn gaussianEliminationF64ExtractSolution(
    rows: usize,
    cols: usize,
    a: []f64,
    b: []f64,
    x: []f64,
) GaussF64Error!void {
    std.debug.assert(a.len >= rows * cols);
    std.debug.assert(b.len >= rows);
    std.debug.assert(x.len >= cols);

    const eps: f64 = 1e-12;

    // Check for inconsistency (0 = non-zero).
    var row_idx: usize = 0;
    while (row_idx < rows) : (row_idx += 1) {
        var all_zero = true;
        var j: usize = 0;
        while (j < cols) : (j += 1) {
            if (@abs(a[row_idx * cols + j]) > eps) {
                all_zero = false;
                break;
            }
        }
        if (all_zero and @abs(b[row_idx]) > eps) {
            return GaussF64Error.SingularMatrix;
        }
    }

    // Read solution: after elimination, each pivot row has the form
    // e_i^T * x = b[i]. Non-pivot columns are treated as 0.
    var col_idx: usize = 0;
    while (col_idx < cols) : (col_idx += 1) {
        x[col_idx] = 0.0;
    }

    var rr: usize = 0;
    while (rr < rows) : (rr += 1) {
        var pivot_col: ?usize = null;
        var jj: usize = 0;
        while (jj < cols) : (jj += 1) {
            if (@abs(a[rr * cols + jj] - 1.0) <= eps) {
                // Check if this is a unit column (pivot).
                pivot_col = jj;
                break;
            } else if (@abs(a[rr * cols + jj]) > eps) {
                // Not in reduced form for this simple scan; skip.
                pivot_col = null;
                break;
            }
        }
        if (pivot_col) |pc| {
            x[pc] = b[rr];
        }
    }
}

/// Solve a linear system A * x = b over the integers using
/// Gaussian-style elimination on an explicit row-major dense matrix
/// of 64-bit signed integers.
///
/// All arithmetic is performed in `i64` without introducing
/// fractions. The elimination phase uses only integer operations
/// (addition, subtraction, and multiplication). During solution
/// extraction we require that each pivot equation admits an integer
/// solution; otherwise `error.NonIntegralSolution` is returned.
///
/// Parameters:
///   rows: number of rows in A
///   cols: number of columns in A (and size of x)
///   a:    slice of length rows * cols, row-major (modified in-place)
///   b:    slice of length rows (RHS, modified in-place)
///   x:    slice of length cols (output solution, fully overwritten)
///
/// On success, `x` contains one integer solution. On inconsistent or
/// underdetermined systems with no integer solution, returns either
/// `error.SingularMatrix` or `error.NonIntegralSolution`.
pub fn gaussianEliminationI64(
    rows: usize,
    cols: usize,
    a: []i64,
    b: []i64,
    x: []i64,
) GaussIntError!void {
    gaussianEliminationI64Eliminate(rows, cols, a, b);
    try gaussianEliminationI64ExtractSolution(rows, cols, a, b, x);
}

/// Perform in-place integer Gaussian elimination on the system
/// A * x = b, using only integer operations. This function does not
/// detect inconsistency or non-integrality; call
/// `gaussianEliminationI64ExtractSolution` afterwards.
pub fn gaussianEliminationI64Eliminate(
    rows: usize,
    cols: usize,
    a: []i64,
    b: []i64,
) void {
    std.debug.assert(a.len >= rows * cols);
    std.debug.assert(b.len >= rows);

    var r: usize = 0;
    var c: usize = 0;

    // Forward elimination with a pivot in each column where possible.
    while (r < rows and c < cols) : (c += 1) {
        // Find pivot row with largest absolute value in column c.
        var pivot_row: ?usize = null;
        var best_val: u64 = 0;
        var i: usize = r;
        while (i < rows) : (i += 1) {
            const val: u64 = @abs(a[i * cols + c]);
            if (val > best_val) {
                best_val = val;
                pivot_row = i;
            }
        }

        if (pivot_row == null or best_val == 0) {
            // Column is effectively zero, move to next column (free variable).
            continue;
        }

        const pr = pivot_row.?;
        // Swap current row r with pivot row pr.
        if (pr != r) {
            var j_swap: usize = c;
            while (j_swap < cols) : (j_swap += 1) {
                const idx1 = r * cols + j_swap;
                const idx2 = pr * cols + j_swap;
                const tmp = a[idx1];
                a[idx1] = a[idx2];
                a[idx2] = tmp;
            }
            const tmp_b = b[r];
            b[r] = b[pr];
            b[pr] = tmp_b;
        }

        const pivot = a[r * cols + c];
        if (pivot == 0) {
            continue;
        }

        // Eliminate this column from rows below using integer-only
        // operations: new_row = pivot * row_i - factor * pivot_row.
        var row2: usize = r + 1;
        while (row2 < rows) : (row2 += 1) {
            const factor = a[row2 * cols + c];
            if (factor == 0) continue;

            var j2: usize = c;
            while (j2 < cols) : (j2 += 1) {
                const idx2 = row2 * cols + j2;
                const idxr = r * cols + j2;
                a[idx2] = pivot * a[idx2] - factor * a[idxr];
            }
            b[row2] = pivot * b[row2] - factor * b[r];
        }

        r += 1;
    }
}

/// After `gaussianEliminationI64Eliminate` has transformed `a` and
/// `b` into an upper-triangular form, extract an integer solution
/// vector into `x` using back-substitution. Returns
/// `error.SingularMatrix` for inconsistent systems and
/// `error.NonIntegralSolution` if a pivot equation does not admit an
/// integer solution.
pub fn gaussianEliminationI64ExtractSolution(
    rows: usize,
    cols: usize,
    a: []i64,
    b: []i64,
    x: []i64,
) GaussIntError!void {
    std.debug.assert(a.len >= rows * cols);
    std.debug.assert(b.len >= rows);
    std.debug.assert(x.len >= cols);

    // Initialize solution to zero (free variables default to 0).
    var j_init: usize = 0;
    while (j_init < cols) : (j_init += 1) {
        x[j_init] = 0;
    }

    // Back-substitution from bottom row to top.
    var r: usize = rows;
    while (r > 0) {
        r -= 1;

        // Find first non-zero coefficient in this row to act as pivot.
        var pivot_col: ?usize = null;
        var c: usize = 0;
        while (c < cols) : (c += 1) {
            if (a[r * cols + c] != 0) {
                pivot_col = c;
                break;
            }
        }

        if (pivot_col == null) {
            // All-zero row: either redundant (0 = 0) or inconsistent (0 = b).
            if (b[r] != 0) {
                return GaussIntError.SingularMatrix;
            }
            continue;
        }

        const pc = pivot_col.?;
        const pivot = a[r * cols + pc];

        // Compute the contribution from already-known variables.
        var sum_known: i64 = 0;
        var j2: usize = pc + 1;
        while (j2 < cols) : (j2 += 1) {
            sum_known += a[r * cols + j2] * x[j2];
        }

        const numer = b[r] - sum_known;

        // Require that numer is divisible by pivot to keep x integer.
        if (pivot == 0) {
            return GaussIntError.SingularMatrix;
        }

        if (@mod(numer, pivot) != 0) {
            return GaussIntError.NonIntegralSolution;
        }

        x[pc] = @divTrunc(numer, pivot);
    }
}

/// Solve a linear system A * x = b over GF(2) (mod 2 arithmetic),
/// where A is represented as an array of `u64` rows, each bit being a
/// coefficient (0 or 1). Up to 64 columns/variables are supported.
///
/// Parameters:
///   num_rows: number of rows in A
///   num_cols: number of columns in A (<= 64)
///   rows:     slice of length >= num_rows, each entry is a bit row
///             (modified in-place during elimination)
///   rhs:      slice of length >= num_rows, each entry is 0 or 1
///             (modified in-place during elimination)
///   solution: slice of length >= num_cols, each entry will be 0 or 1
///             (fully overwritten with the result)
///
/// On success, writes one solution into `solution` (free variables are
/// set to 0). Returns `error.NoSolution` if the system is inconsistent.
/// If you need the original `rows`/`rhs`, copy them before calling.
pub fn gaussianEliminationMod2(
    num_rows: usize,
    num_cols: usize,
    rows: []u64,
    rhs: []u1,
    solution: []u1,
) GaussMod2Error!void {
    gaussianEliminationMod2Eliminate(num_rows, num_cols, rows, rhs);
    try gaussianEliminationMod2ExtractSolution(num_rows, num_cols, rows, rhs, solution);
}

/// Perform in-place Gaussian elimination over GF(2) on the system
/// A * x = b. The bit rows `rows` and RHS `rhs` are transformed to
/// reduced row echelon form. This function does not check for
/// inconsistency; call `gaussianEliminationMod2ExtractSolution`
/// afterwards to detect `error.NoSolution` and read a solution.
pub fn gaussianEliminationMod2Eliminate(
    num_rows: usize,
    num_cols: usize,
    rows: []u64,
    rhs: []u1,
) void {
    std.debug.assert(num_cols <= 64);
    std.debug.assert(rows.len >= num_rows);
    std.debug.assert(rhs.len >= num_rows);

    var r: usize = 0;
    var c: usize = 0;

    // Forward elimination to reduced row echelon form.
    while (r < num_rows and c < num_cols) : (c += 1) {
        const mask = @as(u64, 1) << @intCast(c);

        // Find pivot row with bit `c` set.
        var pivot: ?usize = null;
        var i: usize = r;
        while (i < num_rows) : (i += 1) {
            if ((rows[i] & mask) != 0) {
                pivot = i;
                break;
            }
        }

        if (pivot == null) {
            continue; // Free variable column.
        }

        const pr = pivot.?;
        if (pr != r) {
            const tmp_row = rows[r];
            rows[r] = rows[pr];
            rows[pr] = tmp_row;

            const tmp_rhs = rhs[r];
            rhs[r] = rhs[pr];
            rhs[pr] = tmp_rhs;
        }

        // Eliminate this bit from all other rows.
        var row2: usize = 0;
        while (row2 < num_rows) : (row2 += 1) {
            if (row2 == r) continue;
            if ((rows[row2] & mask) != 0) {
                rows[row2] ^= rows[r];
                rhs[row2] ^= rhs[r];
            }
        }

        r += 1;
    }
}

/// After `gaussianEliminationMod2Eliminate` has produced reduced row
/// echelon form in `rows` and `rhs`, extract one solution vector into
/// `solution`. Free variables are set to 0. Returns `error.NoSolution`
/// if an inconsistent row is present.
pub fn gaussianEliminationMod2ExtractSolution(
    num_rows: usize,
    num_cols: usize,
    rows: []u64,
    rhs: []u1,
    solution: []u1,
) GaussMod2Error!void {
    std.debug.assert(num_cols <= 64);
    std.debug.assert(rows.len >= num_rows);
    std.debug.assert(rhs.len >= num_rows);
    std.debug.assert(solution.len >= num_cols);

    // Check for inconsistency: 0 = 1 rows.
    var row_idx: usize = 0;
    while (row_idx < num_rows) : (row_idx += 1) {
        if (rows[row_idx] == 0 and rhs[row_idx] == 1) {
            return GaussMod2Error.NoSolution;
        }
    }

    // Default all variables to 0.
    var j: usize = 0;
    while (j < num_cols) : (j += 1) {
        solution[j] = 0;
    }

    // For each non-zero row, determine pivot column and assign solution.
    var rr: usize = 0;
    while (rr < num_rows) : (rr += 1) {
        const row_mask = rows[rr];
        if (row_mask == 0) continue;

        // Find the least significant set bit as pivot.
        const lsb_index: u6 = @intCast(@ctz(row_mask));
        if (lsb_index >= num_cols) continue;
        solution[lsb_index] = rhs[rr];
    }
}

test "gaussianEliminationF64 simple 2x2" {
    // Solve: [2 1; 1 -1] * x = [4; 1]
    // Solution: x0 = 5/3, x1 = 2/3
    var a = [_]f64{
        2.0, 1.0,
        1.0, -1.0,
    };
    var b = [_]f64{ 4.0, 1.0 };
    var x: [2]f64 = undefined;
    try gaussianEliminationF64(2, 2, &a, &b, &x);

    const eps: f64 = 1e-9;
    try std.testing.expect(@abs(x[0] - 5.0 / 3.0) < eps);
    try std.testing.expect(@abs(x[1] - 2.0 / 3.0) < eps);
}

test "gaussianEliminationI64 simple 2x2 integer solution" {
    // Solve over Z:
    // [1 2] [x0] = [5]
    // [3 4] [x1]   [11]
    // Solution: x0 = 1, x1 = 2
    var a = [_]i64{
        1, 2,
        3, 4,
    };
    var b = [_]i64{ 5, 11 };
    var x: [2]i64 = undefined;
    try gaussianEliminationI64(2, 2, &a, &b, &x);
    try std.testing.expectEqual(@as(i64, 1), x[0]);
    try std.testing.expectEqual(@as(i64, 2), x[1]);
}

test "gaussianEliminationI64 inconsistent system" {
    // x0 + x1 = 1
    // 2x0 + 2x1 = 3  (inconsistent)
    var a = [_]i64{
        1, 1,
        2, 2,
    };
    var b = [_]i64{ 1, 3 };
    var x: [2]i64 = undefined;
    try std.testing.expectError(GaussIntError.SingularMatrix, gaussianEliminationI64(2, 2, &a, &b, &x));
}

test "gaussianEliminationI64 non-integral solution" {
    // 2x0 = 1 has no integer solution.
    var a = [_]i64{
        2,
    };
    var b = [_]i64{1};
    var x: [1]i64 = undefined;
    try std.testing.expectError(GaussIntError.NonIntegralSolution, gaussianEliminationI64(1, 1, &a, &b, &x));
}

test "gaussianEliminationMod2 simple system" {
    // System over GF(2):
    // x0 ^ x1 = 1
    //        x1 = 0
    // Represented as:
    // [1 1] [x0] = [1]
    // [0 1] [x1]   [0]
    var rows = [_]u64{
        0b11,
        0b10,
    };
    var rhs = [_]u1{ 1, 0 };
    var sol: [2]u1 = undefined;
    try gaussianEliminationMod2(2, 2, &rows, &rhs, &sol);
    try std.testing.expectEqual(@as(u1, 1), sol[0]);
    try std.testing.expectEqual(@as(u1, 0), sol[1]);
}
