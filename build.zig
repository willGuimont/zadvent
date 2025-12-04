const std = @import("std");

pub const current_year = "2025";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const run_step = b.step("solve", "Run and print solution(s)");
    const test_step = b.step("test", "Run unit tests for solution(s)");

    // Top-level options (use b.option)
    const days_option = b.option([]const u8, "days", "Solution day(s), e.g. '5', '1..7', '..12' (end-inclusive)");
    const year_option = b.option([]const u8, "year", b.fmt("Solution directory (default: {s})", .{current_year})) orelse current_year;
    const timer = b.option(bool, "time", "Print performance time of each solution (default: true)") orelse true;
    const color = b.option(bool, "color", "Print ANSI color-coded output (default: true)") orelse true;
    const stop_at_failure = b.option(bool, "fail-stop", "If a solution returns an error, exit (default: false)") orelse false;
    _ = stop_at_failure;
    const part = b.option([]const u8, "part", "Select which solution part to run ('1','2','both')") orelse "both";

    const write_runner = b.addWriteFiles();

    // decide which days to generate for
    var days_to_generate: []usize = &[_]usize{}; // default empty
    if (days_option) |days_str| {
        const allocator = b.allocator;
        const parsed = parseIntRange(allocator, days_str, usize) catch {
            const fail = b.addFail("Invalid range string for -Ddays");
            run_step.dependOn(&fail.step);
            test_step.dependOn(&fail.step);
            return;
        };
        // convert []const usize to owned slice of usize
        const tmp = allocator.alloc(usize, parsed.len) catch {
            const fail = b.addFail("Out of memory allocating parsed days");
            run_step.dependOn(&fail.step);
            test_step.dependOn(&fail.step);
            return;
        };
        for (0..parsed.len) |i| tmp[i] = parsed[i];
        days_to_generate = tmp;
        // free later not required here; build process ephemeral
    }

    const runner_path = write_runner.add("aoc_runner.zig", buildRunnerSource(year_option, days_to_generate, timer, color, part));

    const runner_mod = b.createModule(.{
        .root_source_file = runner_path,
        .target = target,
        .optimize = optimize,
    });

    const runner_exe = b.addExecutable(.{
        .name = b.fmt("advent-of-code-{s}", .{year_option}),
        .root_module = runner_mod,
    });

    runner_exe.step.dependOn(&write_runner.step);
    const run_cmd = b.addRunArtifact(runner_exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.setCwd(b.path("./"));
    b.installArtifact(runner_exe);

    // If no days were provided, fail the run and test steps with a helpful message
    if (days_option == null) {
        const fail = b.addFail("Please select the solution day(s) using -Ddays");
        run_step.dependOn(&fail.step);
        test_step.dependOn(&fail.step);
    }

    // create tests for specified day modules if any
    if (days_option) |days_str| {
        const allocator = b.allocator;
        const parsed = parseIntRange(allocator, days_str, usize) catch {
            const fail = b.addFail("Invalid range string for -Ddays");
            run_step.dependOn(&fail.step);
            test_step.dependOn(&fail.step);
            return;
        };
        for (parsed) |day| {
            if (day > 99) break; // sane guard
            const day_path = b.path(b.fmt("src/{s}/day{d:0>2}.zig", .{ year_option, day }));
            const day_mod = b.createModule(.{
                .root_source_file = day_path,
                .target = target,
                .optimize = optimize,
            });
            runner_mod.addImport(b.fmt("day_{d}", .{day}), day_mod);

            const day_test = b.addTest(.{
                .name = b.fmt("day-{d}-test", .{day}),
                .root_module = day_mod,
            });
            const run_day_test = b.addRunArtifact(day_test);
            test_step.dependOn(&run_day_test.step);
        }
    }
}

// removed tryOrFail helper; errors handled inline

fn buildRunnerSource(year: []const u8, days: []usize, use_timer: bool, use_color: bool, part_opt: []const u8) []const u8 {
    // Minimal placeholder runner source. Replace with generator later.
    _ = year;
    _ = days;
    _ = use_timer;
    _ = use_color;
    _ = part_opt;
    return "pub fn main() anyerror!void { return; }";
}

// Parse a compact integer range string into an allocator-allocated slice of integers.
fn parseIntRange(allocator: std.mem.Allocator, string: []const u8, comptime T: type) ![]T {
    const fmt = std.fmt;
    var dot_index: ?usize = null;
    for (0..string.len) |i| {
        if (string[i] == '.') {
            dot_index = i;
            break;
        }
    }
    if (dot_index) |first_dot_index| {
        if (first_dot_index == 0 and string.len > 1 and string[1] == '.') {
            // ..N form
            if (string.len <= 2) return error.InvalidCharacter;
            const last = try fmt.parseUnsigned(T, string[2..], 10);
            const list = try allocator.alloc(T, last);
            for (0..list.len) |i| {
                list[i] = @as(T, i + 1);
            }
            return list;
        } else if (string.len > first_dot_index + 2 and string[first_dot_index + 1] == '.') {
            const first = try fmt.parseUnsigned(T, string[0..first_dot_index], 10);
            const last = try fmt.parseUnsigned(T, string[first_dot_index + 2 ..], 10);
            if (last < first) return error.InvalidCharacter;
            const cnt = last - first + 1;
            const list = try allocator.alloc(T, cnt);
            for (0..list.len) |i| {
                list[i] = @as(T, first + i);
            }
            return list;
        } else return error.InvalidCharacter;
    } else {
        const v = try fmt.parseUnsigned(T, string, 10);
        const list = try allocator.alloc(T, 1);
        list[0] = v;
        return list;
    }
}

pub const Day = u8;
