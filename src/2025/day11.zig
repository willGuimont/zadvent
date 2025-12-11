const std = @import("std");
const lib = @import("lib");
const str_utils = lib.str_utils;
const FloydWarshall = lib.floyd_warshall.FloydWarshall;
const ArrayStack = lib.stack.ArrayStack;

var buf: [2048]u8 = undefined;
const max_nodes: usize = 590;
const max_connections: usize = 25;

const MemoMap = std.StringHashMap(usize);
const MemoMapForEnd = std.StringHashMap(MemoMap);
const VisitedSet = std.StaticBitSet(max_nodes);

var global_memo: ?MemoMapForEnd = null;

fn getMemoForEnd(allocator: std.mem.Allocator, end_name: []const u8) !*MemoMap {
    if (global_memo == null) {
        global_memo = MemoMapForEnd.init(allocator);
    }

    const em = &global_memo.?;
    if (em.getPtr(end_name)) |mm| {
        return mm;
    }

    const new_mm = MemoMap.init(allocator);
    try em.put(end_name, new_mm);
    return em.getPtr(end_name).?;
}

const NodeList = std.StringHashMap(void);
const Node = struct {
    id: usize,
    name: []const u8,
    connectionsNames: NodeList,
};

fn isProtected(name: []const u8) bool {
    return std.mem.eql(u8, name, "you") or std.mem.eql(u8, name, "out") or std.mem.eql(u8, name, "svr") or std.mem.eql(u8, name, "dac") or std.mem.eql(u8, name, "fft");
}

fn dfsPaths(
    graph: *const std.StringHashMap(Node),
    current_name: []const u8,
    end_name: []const u8,
    vis: *VisitedSet,
    memo: *MemoMap,
) !usize {
    if (memo.get(current_name)) |cached| return cached;

    const current = graph.get(current_name).?;

    var total: usize = 0;
    var kit = current.connectionsNames.keyIterator();
    while (kit.next()) |conn_name_pt| {
        const conn_name = conn_name_pt.*;
        // Direct edge to end target.
        if (std.mem.eql(u8, conn_name, end_name)) {
            total += 1;
            continue;
        }

        const connection = graph.get(conn_name).?;
        if (vis.isSet(connection.id)) continue;

        vis.set(connection.id);
        const sub = try dfsPaths(graph, conn_name, end_name, vis, memo);
        vis.unset(connection.id);
        total += sub;
    }

    try memo.put(current_name, total);
    return total;
}

fn findAllPaths(allocator: std.mem.Allocator, graph: std.StringHashMap(Node), start: []const u8, end: []const u8) !usize {
    const starting_node = graph.get(start).?;

    var visited = VisitedSet.initEmpty();
    visited.set(starting_node.id);

    const memo = try getMemoForEnd(allocator, end);
    return try dfsPaths(&graph, starting_node.name, end, &visited, memo);
}

fn findAllPathsDacFft(allocator: std.mem.Allocator, graph: std.StringHashMap(Node)) !usize {
    const svr2dac = try findAllPaths(allocator, graph, "svr", "dac");
    const svr2fft = try findAllPaths(allocator, graph, "svr", "fft");
    const fft2dac = try findAllPaths(allocator, graph, "fft", "dac");
    const dac2fft = try findAllPaths(allocator, graph, "dac", "fft");
    const dac2out = try findAllPaths(allocator, graph, "dac", "out");
    const fft2out = try findAllPaths(allocator, graph, "fft", "out");

    return svr2dac * dac2fft * fft2out + svr2fft * fft2dac * dac2out;
}

pub fn part1(input: []const u8) ![]const u8 {
    const allocator = std.heap.smp_allocator;
    var node_map = std.StringHashMap(Node).init(allocator);

    var num_nodes: usize = 0;
    const slice = input[0 .. input.len - 1];
    const first_nl = std.mem.indexOfScalar(u8, slice, '\n') orelse slice.len;
    const first_line = slice[0..first_nl];
    const has_markers = std.mem.eql(u8, first_line, "#part1");

    var it = std.mem.splitScalar(u8, slice, '\n');
    if (has_markers) {
        var in_part1 = false;
        while (it.next()) |line| {
            if (line.len == 0) continue;

            if (std.mem.eql(u8, line, "#part1")) {
                in_part1 = true;
                continue;
            }
            if (std.mem.eql(u8, line, "#part2")) {
                // End of part 1 section in example input.
                break;
            }
            if (!in_part1) continue;

            const parts = str_utils.splitOnce(line, ':');
            const name = parts.before;

            var to_nodes = NodeList.init(allocator);
            const trimmed_after = std.mem.trim(u8, parts.after, " ");
            var node_it = std.mem.splitScalar(u8, trimmed_after, ' ');
            while (node_it.next()) |to_node| {
                if (to_node.len == 0) continue;
                try to_nodes.put(to_node, {});
            }

            try node_map.put(name, Node{ .id = num_nodes, .name = name, .connectionsNames = to_nodes });
            num_nodes += 1;
        }
    } else {
        // Real input: just parse all non-empty, non-comment lines.
        while (it.next()) |line| {
            if (line.len == 0) continue;
            if (line[0] == '#') continue;

            const parts = str_utils.splitOnce(line, ':');
            const name = parts.before;

            var to_nodes = NodeList.init(allocator);
            const trimmed_after = std.mem.trim(u8, parts.after, " ");
            var node_it = std.mem.splitScalar(u8, trimmed_after, ' ');
            while (node_it.next()) |to_node| {
                if (to_node.len == 0) continue;
                try to_nodes.put(to_node, {});
            }

            try node_map.put(name, Node{ .id = num_nodes, .name = name, .connectionsNames = to_nodes });
            num_nodes += 1;
        }
    }

    const paths = try findAllPaths(allocator, node_map, "you", "out");

    return std.fmt.bufPrint(&buf, "{d}", .{paths}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    const allocator = std.heap.smp_allocator;
    var node_map = std.StringHashMap(Node).init(allocator);

    var num_nodes: usize = 0;
    const slice = input[0 .. input.len - 1];
    const first_nl = std.mem.indexOfScalar(u8, slice, '\n') orelse slice.len;
    const first_line = slice[0..first_nl];
    const has_markers = std.mem.eql(u8, first_line, "#part1");

    var it = std.mem.splitScalar(u8, slice, '\n');
    if (has_markers) {
        var in_part2 = false;
        while (it.next()) |line| {
            if (line.len == 0) continue;

            if (std.mem.eql(u8, line, "#part2")) {
                in_part2 = true;
                continue;
            }
            if (!in_part2) continue;
            if (line[0] == '#') continue;

            const parts = str_utils.splitOnce(line, ':');
            const name = parts.before;

            var to_nodes = NodeList.init(allocator);
            const trimmed_after = std.mem.trim(u8, parts.after, " ");
            var node_it = std.mem.splitScalar(u8, trimmed_after, ' ');
            while (node_it.next()) |to_node| {
                if (to_node.len == 0) continue;
                try to_nodes.put(to_node, {});
            }

            try node_map.put(name, Node{ .id = num_nodes, .name = name, .connectionsNames = to_nodes });
            num_nodes += 1;
        }
    } else {
        // Real input: just parse all non-empty, non-comment lines.
        while (it.next()) |line| {
            if (line.len == 0) continue;
            if (line[0] == '#') continue;

            const parts = str_utils.splitOnce(line, ':');
            const name = parts.before;

            var to_nodes = NodeList.init(allocator);
            const trimmed_after = std.mem.trim(u8, parts.after, " ");
            var node_it = std.mem.splitScalar(u8, trimmed_after, ' ');
            while (node_it.next()) |to_node| {
                if (to_node.len == 0) continue;
                try to_nodes.put(to_node, {});
            }

            try node_map.put(name, Node{ .id = num_nodes, .name = name, .connectionsNames = to_nodes });
            num_nodes += 1;
        }
    }

    const paths = try findAllPathsDacFft(allocator, node_map);

    return std.fmt.bufPrint(&buf, "{d}", .{paths}) catch "error";
}
