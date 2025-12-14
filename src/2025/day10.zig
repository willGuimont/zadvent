const std = @import("std");
const lib = @import("lib");
const gauss = lib.math.gauss;

var buf: [2048]u8 = undefined;
const max_num_lights: usize = 10;
const max_num_machines: usize = 150;
const max_num_buttons: usize = 1076;

const ProblemError = error{Unsolvable};

const max_states: usize = 1 << max_num_lights;
const ShiftType = std.math.Log2Int(usize);
const ButtonMaskShift = std.math.Log2Int(u32);
const INF: usize = std.math.maxInt(usize);

const Ctx = struct {
    lines: []const []const u8,
    results: []usize,
};

fn job(ctx: *Ctx, index: usize) void {
    const line = ctx.lines[index];
    const presses = solveLine(line) catch unreachable;
    ctx.results[index] = presses;
}

fn minPresses(target_mask: usize, buttons: []const usize, num_lights: usize) !usize {
    if (target_mask == 0) return 0;

    var visited: [max_states]bool = undefined;
    var dist: [max_states]u8 = undefined;
    var queue_state: [max_states]usize = undefined;

    const num_states: usize = @as(usize, 1) << @intCast(num_lights);

    for (0..num_states) |i| {
        visited[i] = false;
    }

    var head: usize = 0;
    var tail: usize = 0;

    queue_state[tail] = 0;
    tail += 1;
    visited[0] = true;
    dist[0] = 0;

    while (head < tail) {
        const cur = queue_state[head];
        head += 1;

        if (cur == target_mask) {
            return dist[cur];
        }

        const d = dist[cur];
        for (buttons) |b| {
            const next = cur ^ b;
            if (!visited[next]) {
                visited[next] = true;
                dist[next] = d + 1;
                queue_state[tail] = next;
                tail += 1;
            }
        }
    }

    return ProblemError.Unsolvable;
}

pub fn part1(input: []const u8) ![]const u8 {
    var result: usize = 0;

    var it = std.mem.splitScalar(u8, input[0 .. input.len - 1], '\n');
    while (it.next()) |line| {
        var target: usize = undefined;
        var num_lights: u4 = 0;
        var num_buttons: usize = 0;
        var buttons: [max_num_buttons]usize = undefined;

        var parts = std.mem.splitScalar(u8, line, ' ');
        while (parts.next()) |part| {
            if (part[0] == '[') {
                for (part[1 .. part.len - 1]) |c| {
                    target <<= 1;
                    if (c == '#') {
                        target |= 1;
                    }
                    num_lights += 1;
                }
            }
            if (part[0] == '(') {
                var b_it = std.mem.splitScalar(u8, part[1 .. part.len - 1], ',');
                var b_value: usize = 0;
                while (b_it.next()) |button| {
                    const bit_index = try std.fmt.parseInt(u4, button, 10);
                    b_value |= @as(usize, 1) << (num_lights - 1 - bit_index);
                }
                buttons[num_buttons] = b_value;
                num_buttons += 1;
            }
        }

        const N: usize = num_lights;
        const M: usize = num_buttons;

        const presses = try minPresses(target, buttons[0..M], N);
        result += presses;
    }

    return std.fmt.bufPrint(&buf, "{d}", .{result}) catch "error";
}

fn solveLine(line: []const u8) !usize {
    var target_joltage: [max_num_lights]usize = [_]usize{0} ** max_num_lights;
    var num_lights: usize = 0;
    var num_buttons: usize = 0;
    var buttons: [max_num_buttons]usize = undefined;

    var parts = std.mem.splitScalar(u8, line, ' ');
    while (parts.next()) |part| {
        if (part[0] == '(') {
            var b_it = std.mem.splitScalar(u8, part[1 .. part.len - 1], ',');
            var b_value: usize = 0;
            while (b_it.next()) |button| {
                const bit_index = try std.fmt.parseInt(u4, button, 10);
                const shift = @as(ShiftType, @intCast(bit_index));
                b_value |= @as(usize, 1) << shift;
            }
            buttons[num_buttons] = b_value;
            num_buttons += 1;
        }
        if (part[0] == '{') {
            var t_it = std.mem.splitScalar(u8, part[1 .. part.len - 1], ',');
            var jolt_index: usize = 0;
            while (t_it.next()) |light| {
                const target_jolts = try std.fmt.parseInt(usize, light, 10);
                target_joltage[jolt_index] = target_jolts;
                jolt_index += 1;
            }
            num_lights = jolt_index;
        }
    }

    std.debug.assert(num_lights <= max_num_lights);
    std.debug.assert(num_buttons <= max_num_buttons);

    const rows = num_lights;
    const cols = num_buttons;

    // Build integer matrix A (rows x cols) where A[i,j] = 1 if
    // button j affects light i, otherwise 0.
    var a_storage: [max_num_lights * max_num_buttons]i64 = undefined;
    var b_storage: [max_num_lights]i64 = undefined;

    var i: usize = 0;
    while (i < rows) : (i += 1) {
        var j: usize = 0;
        while (j < cols) : (j += 1) {
            const bit = @as(usize, 1) << @intCast(i);
            a_storage[i * cols + j] = if ((buttons[j] & bit) != 0) 1 else 0;
        }
        b_storage[i] = @as(i64, @intCast(target_joltage[i]));
    }

    // Compute a simple upper bound on how many times each button can
    // be pressed: it cannot exceed the minimum target joltage of any
    // light it affects.
    var max_press: [max_num_buttons]usize = undefined;
    var j_btn: usize = 0;
    while (j_btn < cols) : (j_btn += 1) {
        var bound: ?usize = null;
        var li: usize = 0;
        while (li < rows) : (li += 1) {
            const bit = @as(usize, 1) << @intCast(li);
            if ((buttons[j_btn] & bit) != 0) {
                const t = target_joltage[li];
                if (bound == null or t < bound.?) bound = t;
            }
        }
        max_press[j_btn] = bound orelse 0;
    }

    // Work with slices for Gaussian elimination.
    const a_slice = a_storage[0 .. rows * cols];
    const b_slice = b_storage[0..rows];

    // Perform integer Gaussian elimination in-place.
    gauss.gaussianEliminationI64Eliminate(rows, cols, a_slice, b_slice);

    // Determine pivot columns and free columns from the eliminated matrix.
    var is_pivot_col: [max_num_buttons]bool = undefined;
    for (0..cols) |ci| is_pivot_col[ci] = false;

    var pivot_col_for_row: [max_num_lights]?usize = [_]?usize{null} ** max_num_lights;
    i = 0;
    while (i < rows) : (i += 1) {
        var c: usize = 0;
        var pivot_col: ?usize = null;
        while (c < cols) : (c += 1) {
            if (a_slice[i * cols + c] != 0) {
                pivot_col = c;
                break;
            }
        }
        pivot_col_for_row[i] = pivot_col;
        if (pivot_col) |pc| {
            is_pivot_col[pc] = true;
        }
    }

    var free_indices: [max_num_buttons]usize = undefined;
    var num_free: usize = 0;
    var cidx: usize = 0;
    while (cidx < cols) : (cidx += 1) {
        if (!is_pivot_col[cidx]) {
            free_indices[num_free] = cidx;
            num_free += 1;
        }
    }

    var x_storage: [max_num_buttons]i64 = undefined;

    var best_presses: ?usize = null;

    // DFS over assignments to free variables, similar in spirit to
    // part 1's search but operating in the remaining degrees of
    // freedom of the linear system.
    var choice_storage: [max_num_buttons]i64 = undefined;

    const DFS = struct {
        fn go(
            depth: usize,
            num_free_: usize,
            free_idx: []const usize,
            max_press_: []const usize,
            cols_: usize,
            rows_: usize,
            a_: []const i64,
            b_: []const i64,
            x_buf: []i64,
            choice: []i64,
            best: *?usize,
        ) void {
            if (depth == num_free_) {
                // Start with all zeros, then apply chosen free values.
                var j_: usize = 0;
                while (j_ < cols_) : (j_ += 1) {
                    x_buf[j_] = 0;
                }

                var fi: usize = 0;
                while (fi < num_free_) : (fi += 1) {
                    const col = free_idx[fi];
                    x_buf[col] = choice[fi];
                }

                // Back-substitution from bottom row to top, respecting
                // any pre-set free variables in x_buf.
                var ok = true;
                var r_: usize = rows_;
                while (r_ > 0) {
                    r_ -= 1;

                    var pivot_col: ?usize = null;
                    var c_: usize = 0;
                    while (c_ < cols_) : (c_ += 1) {
                        if (a_[r_ * cols_ + c_] != 0) {
                            pivot_col = c_;
                            break;
                        }
                    }

                    if (pivot_col == null) {
                        if (b_[r_] != 0) {
                            ok = false;
                            break;
                        }
                        continue;
                    }

                    const pc = pivot_col.?;
                    const pivot = a_[r_ * cols_ + pc];

                    var sum_known: i64 = 0;
                    var cj: usize = pc + 1;
                    while (cj < cols_) : (cj += 1) {
                        sum_known += a_[r_ * cols_ + cj] * x_buf[cj];
                    }

                    const numer = b_[r_] - sum_known;

                    if (pivot == 0) {
                        ok = false;
                        break;
                    }

                    if (@mod(numer, pivot) != 0) {
                        ok = false;
                        break;
                    }

                    const value = @divTrunc(numer, pivot);
                    if (value < 0) {
                        ok = false;
                        break;
                    }

                    x_buf[pc] = value;
                }

                if (!ok) return;

                var presses: usize = 0;
                j_ = 0;
                while (j_ < cols_) : (j_ += 1) {
                    if (x_buf[j_] < 0) return; // discard
                    presses += @as(usize, @intCast(x_buf[j_]));
                }

                if (best.* == null or presses < best.*.?) {
                    best.* = presses;
                }
                return;
            }

            const col = free_idx[depth];
            const max_p = max_press_[col];

            var v: usize = 0;
            while (v <= max_p) : (v += 1) {
                choice[depth] = @as(i64, @intCast(v));
                go(depth + 1, num_free_, free_idx, max_press_, cols_, rows_, a_, b_, x_buf, choice, best);
            }
        }
    };

    DFS.go(
        0,
        num_free,
        free_indices[0..num_free],
        max_press[0..cols],
        cols,
        rows,
        a_slice,
        b_slice,
        x_storage[0..cols],
        choice_storage[0..num_free],
        &best_presses,
    );

    if (best_presses) |bp| {
        return bp;
    } else {
        return ProblemError.Unsolvable;
    }
}

pub fn part2(input: []const u8) ![]const u8 {
    const allocator = std.heap.smp_allocator;

    var lines = try std.ArrayList([]const u8).initCapacity(allocator, max_num_machines);
    defer lines.deinit(allocator);

    var it = std.mem.splitScalar(u8, input[0 .. input.len - 1], '\n');
    while (it.next()) |line| {
        try lines.append(allocator, line);
    }

    const line_slice = lines.items;

    var results = try allocator.alloc(usize, line_slice.len);
    defer allocator.free(results);

    const ThreadPool = lib.thread_pool.ThreadPool;

    var ctx = Ctx{
        .lines = line_slice,
        .results = results[0..],
    };

    const Pool = ThreadPool(Ctx, job);
    var pool = Pool.init(allocator, &ctx, line_slice.len);
    try pool.run();

    var total: usize = 0;
    for (results) |r| total += r;

    return std.fmt.bufPrint(&buf, "{d}", .{total}) catch "error";
}
