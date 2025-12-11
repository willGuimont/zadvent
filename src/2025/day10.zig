const std = @import("std");
const lib = @import("lib");

var buf: [2048]u8 = undefined;
const max_num_lights: usize = 10;
const max_num_machines: usize = 150;
const max_num_buttons: usize = 1076;

const ProblemError = error{Unsolvable};

const max_states: usize = 1 << max_num_lights;
const ShiftType = std.math.Log2Int(usize);
const ButtonMaskShift = std.math.Log2Int(u32);
const INF: usize = std.math.maxInt(usize);

const StateKey = struct {
    mask: u32,
    joltage: [max_num_lights]u16,
};

const Ctx = struct {
    allocator: std.mem.Allocator,
    lines: []const []const u8,
    results: []usize,
};

fn job(ctx: *Ctx, index: usize) void {
    const line = ctx.lines[index];
    const presses = solveLine(line, ctx.allocator) catch unreachable;
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

fn isButtonAvailable(i: usize, mask: u32) bool {
    if (i >= 32) return false;
    const bit = @as(u32, 1) << @as(ButtonMaskShift, @intCast(i));
    return (mask & bit) != 0;
}

fn exploreCombinations(
    idx: usize,
    remaining: usize,
    counts: []usize,
    matching_buttons: []const usize,
    joltage: []const usize,
    buttons: []const usize,
    new_mask: u32,
    num_lights: usize,
    caps: []const usize,
    cache: *std.AutoHashMap(StateKey, usize),
    best_result: *usize,
) void {
    const num_matching = matching_buttons.len;

    if (idx + 1 == num_matching) {
        if (remaining > caps[idx]) return;
        counts[idx] = remaining;

        var new_joltage: [max_num_lights]usize = undefined;
        for (0..num_lights) |i| new_joltage[i] = joltage[i];

        var good = true;
        var total_presses: usize = 0;

        for (matching_buttons, 0..) |button_index, mi| {
            const cnt = counts[mi];
            if (cnt == 0) continue;
            total_presses += cnt;

            const mask = buttons[button_index];
            var j: usize = 0;
            while (j < num_lights) : (j += 1) {
                const bit = @as(usize, 1) << @as(ShiftType, @intCast(j));
                if ((mask & bit) == 0) continue;
                if (new_joltage[j] >= cnt) {
                    new_joltage[j] -= cnt;
                } else {
                    good = false;
                    break;
                }
            }
            if (!good) break;
        }

        if (good) {
            const res = dfsJolts(new_joltage[0..num_lights], new_mask, buttons, num_lights, cache);
            if (res != INF) {
                const total = total_presses + res;
                if (total < best_result.*) best_result.* = total;
            }
        }
    } else {
        const max_k = @min(remaining, caps[idx]);
        var k: usize = 0;
        while (k <= max_k) : (k += 1) {
            counts[idx] = k;
            exploreCombinations(idx + 1, remaining - k, counts, matching_buttons, joltage, buttons, new_mask, num_lights, caps, cache, best_result);
        }
    }
}

fn dfsJolts(
    joltage: []const usize,
    available_buttons_mask: u32,
    buttons: []const usize,
    num_lights: usize,
    cache: *std.AutoHashMap(StateKey, usize),
) usize {
    if (num_lights == 0) return 0;
    var all_zero = true;
    var i: usize = 0;
    while (i < num_lights) : (i += 1) {
        if (joltage[i] != 0) {
            all_zero = false;
            break;
        }
    }
    if (all_zero) return 0;

    var key = StateKey{
        .mask = available_buttons_mask,
        .joltage = [_]u16{0} ** max_num_lights,
    };
    i = 0;
    while (i < num_lights) : (i += 1) {
        // Problem input guarantees small joltage values
        key.joltage[i] = @intCast(joltage[i]);
    }

    if (cache.get(key)) |cached| {
        return cached;
    }

    var best_index: usize = 0;
    var best_buttons_count: usize = std.math.maxInt(usize);
    var best_value: usize = 0;
    var have_best = false;

    // Find the joltage value with the lowest number of buttons affecting it.
    // If there is a tie, pick the highest joltage value.
    i = 0;
    while (i < num_lights) : (i += 1) {
        const v = joltage[i];
        if (v == 0) continue;

        var count_buttons: usize = 0;
        for (buttons, 0..) |mask, bi| {
            if (!isButtonAvailable(bi, available_buttons_mask)) continue;
            const bit = @as(usize, 1) << @as(ShiftType, @intCast(i));
            if ((mask & bit) != 0) {
                count_buttons += 1;
            }
        }

        if (count_buttons == 0) continue;

        if (!have_best or count_buttons < best_buttons_count or
            (count_buttons == best_buttons_count and v > best_value))
        {
            have_best = true;
            best_index = i;
            best_buttons_count = count_buttons;
            best_value = v;
        }
    }

    if (!have_best) return INF;

    const mini = best_index;
    const min_value = best_value;

    // Collect all buttons that affect position `mini` and are still available.
    var matching_storage: [max_num_buttons]usize = undefined;
    var num_matching: usize = 0;
    for (buttons, 0..) |mask, bi| {
        if (!isButtonAvailable(bi, available_buttons_mask)) continue;
        const bit = @as(usize, 1) << @as(ShiftType, @intCast(mini));
        if ((mask & bit) != 0) {
            matching_storage[num_matching] = bi;
            num_matching += 1;
        }
    }

    var result: usize = INF;

    if (num_matching > 0) {
        // Compute per-button maximum press counts based on current joltage
        var caps_storage: [max_num_buttons]usize = undefined;
        const caps = caps_storage[0..num_matching];
        var mi: usize = 0;
        while (mi < num_matching) : (mi += 1) {
            const bi = matching_storage[mi];
            const mask = buttons[bi];
            var cap: usize = INF;
            var j: usize = 0;
            while (j < num_lights) : (j += 1) {
                const bit = @as(usize, 1) << @as(ShiftType, @intCast(j));
                if ((mask & bit) != 0) {
                    const v = joltage[j];
                    if (v < cap) cap = v;
                }
            }
            if (cap == INF) cap = 0;
            caps[mi] = cap;
        }

        // Sort matching buttons by increasing cap to prune earlier
        mi = 0;
        while (mi < num_matching) : (mi += 1) {
            var min_pos = mi;
            var mj: usize = mi + 1;
            while (mj < num_matching) : (mj += 1) {
                if (caps[mj] < caps[min_pos]) {
                    min_pos = mj;
                }
            }
            if (min_pos != mi) {
                const tmp_b = matching_storage[mi];
                matching_storage[mi] = matching_storage[min_pos];
                matching_storage[min_pos] = tmp_b;

                const tmp_c = caps[mi];
                caps[mi] = caps[min_pos];
                caps[min_pos] = tmp_c;
            }
        }

        // New mask: disable all matching buttons for deeper recursion.
        var new_mask = available_buttons_mask;
        for (matching_storage[0..num_matching]) |bi| {
            const bit = @as(u32, 1) << @as(ButtonMaskShift, @intCast(bi));
            new_mask &= ~bit;
        }

        // Enumerate all ways to distribute `min_value` presses among
        // the matching buttons.
        var counts_storage: [max_num_buttons]usize = undefined;
        const counts = counts_storage[0..num_matching];
        for (counts) |*c| c.* = 0;

        exploreCombinations(0, min_value, counts, matching_storage[0..num_matching], joltage, buttons, new_mask, num_lights, caps, cache, &result);
    }

    // Store in cache (including INF results to prune future calls)
    cache.put(key, result) catch {};

    return result;
}

pub fn part1(input: []const u8) ![]const u8 {
    var result: usize = 0;

    var it = std.mem.splitAny(u8, input[0 .. input.len - 1], "\n");
    while (it.next()) |line| {
        var target: usize = undefined;
        var num_lights: u4 = 0;
        var num_buttons: usize = 0;
        var buttons: [max_num_buttons]usize = undefined;

        var parts = std.mem.splitAny(u8, line, " ");
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
                var b_it = std.mem.splitAny(u8, part[1 .. part.len - 1], ",");
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

fn solveLine(line: []const u8, allocator: std.mem.Allocator) !usize {
    var target_joltage: [max_num_lights]usize = [_]usize{0} ** max_num_lights;
    var num_lights: usize = 0;
    var num_buttons: usize = 0;
    var buttons: [max_num_buttons]usize = undefined;

    var parts = std.mem.splitAny(u8, line, " ");
    while (parts.next()) |part| {
        if (part[0] == '(') {
            var b_it = std.mem.splitAny(u8, part[1 .. part.len - 1], ",");
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
            var t_it = std.mem.splitAny(u8, part[1 .. part.len - 1], ",");
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

    var mask: u32 = 0;
    var bi: usize = 0;
    while (bi < num_buttons) : (bi += 1) {
        const bit = @as(u32, 1) << @as(ButtonMaskShift, @intCast(bi));
        mask |= bit;
    }

    var cache = std.AutoHashMap(StateKey, usize).init(allocator);
    defer cache.deinit();

    const presses = dfsJolts(target_joltage[0..num_lights], mask, buttons[0..num_buttons], num_lights, &cache);
    return presses;
}

pub fn part2(input: []const u8) ![]const u8 {
    const allocator = std.heap.page_allocator;

    var lines = try std.ArrayList([]const u8).initCapacity(allocator, max_num_machines);
    defer lines.deinit(allocator);

    var it = std.mem.splitAny(u8, input[0 .. input.len - 1], "\n");
    while (it.next()) |line| {
        try lines.append(allocator, line);
    }

    const line_slice = lines.items;

    var results = try allocator.alloc(usize, line_slice.len);
    defer allocator.free(results);

    const ThreadPool = lib.thread_pool.ThreadPool;

    var ctx = Ctx{
        .allocator = allocator,
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
