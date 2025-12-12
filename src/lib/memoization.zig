/// Generic utilities for compile-time inspection of function types and
/// a small memoization helper that can cache results of pure functions.
const std = @import("std");

/// Given a function type `F`, return its result type.
///
/// This expects `F` to be a bare function type (not a pointer-to-function).
fn getReturnTypeOfFn(comptime F: type) type {
    const info = @typeInfo(F);
    if (info != .@"fn") {
        @compileError("Expected a function type");
    }
    return info.@"fn".return_type.?;
}

/// Given a function type `F`, return its parameter metadata slice.
///
/// This can be used together with `paramsToTupleType` to build a tuple
/// type that represents all arguments of `F` in order.
fn getArgumentTypesOfFn(comptime F: type) []const std.builtin.Type.Fn.Param {
    const info = @typeInfo(F);
    if (info != .@"fn") {
        @compileError("Expected a function type");
    }
    return info.@"fn".params;
}

/// Convert a compile-time slice of function parameters into a tuple type.
///
/// Each entry in `params` must have a concrete, non-optional `type` field.
fn paramsToTupleType(comptime params: []const std.builtin.Type.Fn.Param) type {
    var types: [params.len]type = undefined;

    inline for (params, &types) |param, *slot| {
        slot.* = param.type orelse @compileError("Parameter must have a concrete type");
    }

    return std.meta.Tuple(&types);
}

/// Return whether `T` is a function type according to `@typeInfo`.
fn isFn(comptime T: type) bool {
    return @typeInfo(T) == .@"fn";
}

/// Memoize a function `F` by caching its results keyed by its arguments.
///
/// - `F` must be a function type; its parameters are inspected at comptime.
/// - The cache key is a `std.meta.Tuple` of all parameter types of `F`.
/// - The returned type provides `init`, `deinit`, and `call`:
///   - `init(allocator)` creates a memoizer instance.
///   - `deinit()` must be called to free internal allocations.
///   - `call(args)` takes a tuple of arguments matching `F`'s parameters.
///
/// For correctness the function should be *pure* with respect to its
/// arguments: given the same input tuple it should always return the same
/// value and must not rely on hidden mutable state.
pub fn Memoize(comptime F: anytype) type {
    const FType = @TypeOf(F);
    if (!isFn(FType)) {
        @compileError("Expected a function type");
    }

    const info = @typeInfo(FType).@"fn";
    const Params = info.params;

    const Args = paramsToTupleType(Params);
    const Result = info.return_type orelse @compileError("Function must have a return type");

    return struct {
        const Self = @This();

        /// Hash map used to store cached results. The key is a tuple of
        /// all arguments to `F` and the value is the corresponding result.
        cache: std.AutoHashMap(Args, Result),

        /// Initialize a memoizer instance using `allocator`.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .cache = std.AutoHashMap(Args, Result).init(allocator),
            };
        }

        /// Free all memory associated with this memoizer.
        pub fn deinit(self: *Self) void {
            self.cache.deinit();
        }

        /// Call the underlying function `F` with the given argument tuple.
        ///
        /// If the same `args` tuple has been seen before, the cached
        /// result is returned instead of calling `F` again.
        pub fn call(self: *Self, args: Args) !Result {
            if (self.cache.get(args)) |value| {
                return value;
            }

            const result = @call(.auto, F, args);
            try self.cache.put(args, result);
            return result;
        }
    };
}

fn test_fn_1() usize {
    return 2;
}

fn test_fn_2(x: u8) !i32 {
    return @as(i32, x);
}

const TestStruct3 = struct {
    x: u8,
    y: u8,
};

fn test_fn_3(x: u8, y: u8) TestStruct3 {
    return TestStruct3{ .x = x, .y = y };
}

test "getReturnTypeOfFn for simple functions" {
    const t1 = getReturnTypeOfFn(@TypeOf(test_fn_1));
    const t2 = getReturnTypeOfFn(@TypeOf(test_fn_2));
    const t3 = getReturnTypeOfFn(@TypeOf(test_fn_3));

    try std.testing.expectEqual(t1, usize);
    try std.testing.expectEqual(t2, @TypeOf(test_fn_2(2)));
    try std.testing.expectEqual(t3, TestStruct3);
}

test "getArgumentTypesOfFn for simple functions" {
    const t1 = getArgumentTypesOfFn(@TypeOf(test_fn_1));
    const t2 = getArgumentTypesOfFn(@TypeOf(test_fn_2));
    const t3 = getArgumentTypesOfFn(@TypeOf(test_fn_3));

    try std.testing.expectEqual(t1.len, 0);
    try std.testing.expectEqual(t2.len, 1);
    try std.testing.expectEqual(t3.len, 2);
    try std.testing.expectEqual(t3[0].type, u8);
    try std.testing.expectEqual(t3[1].type, u8);
}

test "paramsToTupleType for simple functions" {
    const p1 = getArgumentTypesOfFn(@TypeOf(test_fn_1));
    const Tuple1 = paramsToTupleType(p1);
    const info1 = @typeInfo(Tuple1);
    try std.testing.expect(info1 == .@"struct");
    try std.testing.expect(info1.@"struct".is_tuple);
    try std.testing.expectEqual(info1.@"struct".fields.len, 0);

    const p2 = getArgumentTypesOfFn(@TypeOf(test_fn_2));
    const Tuple2 = paramsToTupleType(p2);
    const info2 = @typeInfo(Tuple2);
    try std.testing.expect(info2 == .@"struct");
    try std.testing.expect(info2.@"struct".is_tuple);
    try std.testing.expectEqual(info2.@"struct".fields.len, 1);
    try std.testing.expectEqual(info2.@"struct".fields[0].type, u8);

    const p3 = getArgumentTypesOfFn(@TypeOf(test_fn_3));
    const Tuple3 = paramsToTupleType(p3);
    const info3 = @typeInfo(Tuple3);
    try std.testing.expect(info3 == .@"struct");
    try std.testing.expect(info3.@"struct".is_tuple);
    try std.testing.expectEqual(info3.@"struct".fields.len, 2);
    try std.testing.expectEqual(info3.@"struct".fields[0].type, u8);
    try std.testing.expectEqual(info3.@"struct".fields[1].type, u8);
}

fn test_memoize_1(x: i32) struct { i32, i32 } {
    const State = struct {
        var call_counter: i32 = 0;
    };
    State.call_counter += 1;
    return .{ x, State.call_counter };
}

test "memoize simple case" {
    const allocator = std.testing.allocator;

    var memoized_1 = Memoize(test_memoize_1).init(allocator);
    defer memoized_1.deinit();

    const call_1 = memoized_1.call(.{1});
    const call_2 = memoized_1.call(.{1});
    const call_3 = memoized_1.call(.{2});

    try std.testing.expectEqual(call_1, .{ 1, 1 });
    try std.testing.expectEqual(call_2, .{ 1, 1 });
    try std.testing.expectEqual(call_3, .{ 2, 2 });
}
