const std = @import("std");
const testing = std.testing;

/// Simple generic thread pool
///
/// It runs `JobFn(ctx, index)` for every `index` in `0..job_count`
/// using up to one worker per CPU (and optionally capped by
/// `max_threads`).
///
/// Example usage:
///
/// const thread_pool = @import("thread_pool.zig");
/// const Ctx = struct {
///     lines: []const []const u8,
///     results: []usize,
/// };
///
/// fn job(c: *Ctx, i: usize) void {
///     const line = c.lines[i];
///     const presses = solveLine(line) catch unreachable;
///     c.results[i] = presses;
/// }
///
/// var ctx = Ctx{ .lines = lines, .results = results };
/// const Pool = thread_pool.ThreadPool(Ctx, job);
/// var pool = Pool.init(allocator, &ctx, lines.len);
/// try pool.run();
pub fn ThreadPool(comptime Ctx: type, comptime JobFn: fn (*Ctx, usize) void) type {
    return struct {
        const Self = @This();
        const Shared = struct {
            ctx: *Ctx,
            next_index: usize,
            job_count: usize,
        };

        allocator: std.mem.Allocator,
        ctx: *Ctx,
        job_count: usize,
        max_threads: ?usize,

        pub fn init(allocator: std.mem.Allocator, ctx: *Ctx, job_count: usize) Self {
            return .{
                .allocator = allocator,
                .ctx = ctx,
                .job_count = job_count,
                .max_threads = null,
            };
        }

        pub fn initMaxThreads(allocator: std.mem.Allocator, ctx: *Ctx, job_count: usize, max_threads: usize) Self {
            return .{
                .allocator = allocator,
                .ctx = ctx,
                .job_count = job_count,
                .max_threads = max_threads,
            };
        }

        pub fn run(self: *Self) !void {
            const job_count = self.job_count;
            if (job_count == 0) return;

            var shared = Shared{
                .ctx = self.ctx,
                .next_index = 0,
                .job_count = job_count,
            };

            const cpu_count = std.Thread.getCpuCount() catch 1;
            const limit = if (self.max_threads) |mt| @min(mt, cpu_count) else cpu_count;
            const worker_count: usize = @min(job_count, limit);

            var threads = try self.allocator.alloc(std.Thread, worker_count);
            defer self.allocator.free(threads);

            for (0..worker_count) |ti| {
                threads[ti] = try std.Thread.spawn(.{}, workerMain, .{&shared});
            }

            for (threads) |*t| t.join();
        }

        fn workerMain(shared_ptr: *Shared) void {
            while (true) {
                const i = @atomicRmw(usize, &shared_ptr.next_index, .Add, 1, .seq_cst);
                if (i >= shared_ptr.job_count) break;

                JobFn(shared_ptr.ctx, i);
            }
        }
    };
}

const TestCtx = struct { results: []usize };

fn job1(c: *TestCtx, index: usize) void {
    c.results[index] = index;
}

fn job2(c: *TestCtx, index: usize) void {
    // Simple deterministic write; if a job runs multiple times
    // or is skipped, the final results check will fail.
    c.results[index] = index + 1;
}

fn runForEachTest(comptime Ctx: type) !void {
    const job_count: usize = 64;
    var results = try testing.allocator.alloc(usize, job_count);
    defer testing.allocator.free(results);

    // Fill with a sentinel to ensure jobs actually write.
    for (results, 0..) |*r, i| {
        _ = i;
        r.* = std.math.maxInt(usize);
    }

    var ctx = Ctx{ .results = results[0..] };

    const Pool = ThreadPool(Ctx, job1);
    var pool = Pool.init(testing.allocator, &ctx, job_count);
    try pool.run();

    var i: usize = 0;
    while (i < job_count) : (i += 1) {
        try testing.expectEqual(i, results[i]);
    }
}

fn runForEachMaxThreadsTest(comptime Ctx: type) !void {
    const job_count: usize = 32;
    var results = try testing.allocator.alloc(usize, job_count);
    defer testing.allocator.free(results);

    for (results, 0..) |*r, i| {
        _ = i;
        r.* = 0;
    }

    var ctx = Ctx{ .results = results[0..] };

    // Use a small max_threads to exercise the cap.
    const Pool = ThreadPool(Ctx, job2);
    var pool = Pool.initMaxThreads(testing.allocator, &ctx, job_count, 2);
    try pool.run();

    var i: usize = 0;
    while (i < job_count) : (i += 1) {
        try testing.expectEqual(i + 1, results[i]);
    }
}

test "forEach processes all jobs" {
    try runForEachTest(TestCtx);
}

test "forEachMaxThreads respects max thread cap" {
    try runForEachMaxThreadsTest(TestCtx);
}
