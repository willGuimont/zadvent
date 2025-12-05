# ZAdvent

Advent of Code solutions using the Zig programming language.

## Setup

Set environment variables for automatic input fetching:

```sh
export AOC_TOKEN="your_session_token_from_adventofcode.com"
export AOC_USER_AGENT="github.com/yourusername/zadvent by your.email@example.com"
```

To get your session token:

1. Log in to [adventofcode.com](https://adventofcode.com)
2. Open browser DevTools (F12)
3. Go to Application/Storage → Cookies
4. Copy the value of the `session` cookie

## Usage

### Run a Single Day

```sh
# Run both parts for day 1
zig build -Ddays=1 solve

# Run only part 1
zig build -Ddays=1 -Dpart=1 solve

# Run only part 2
zig build -Ddays=1 -Dpart=2 solve
```

### Run Multiple Days

```sh
# Run days 1 through 5
zig build -Ddays=1..5 solve

# Run days 1 through 10
zig build -Ddays=..10 solve

# Run specific days (requires separate builds)
zig build -Ddays=1 solve
zig build -Ddays=3 solve
zig build -Ddays=5 solve
```

### Options

```sh
# Disable timing information
zig build -Ddays=1 -Dtime=false solve

# Disable colored output
zig build -Ddays=1 -Dcolor=false solve

# Specify a different year (default: 2025)
zig build -Dyear=2024 -Ddays=1 solve
```

### Manual Input Fetching

Inputs are fetched automatically when running solutions. To manually fetch inputs:

```sh
zig build -Ddays=1 fetch-inputs
zig build -Ddays=1..5 fetch-inputs
```

## Project Structure

```
zadvent/
├── build.zig              # Build configuration
├── src/
│   ├── 2025/
│   │   ├── day01.zig      # Day 1 solution
│   │   ├── day02.zig      # Day 2 solution
│   │   └── ...
│   ├── fetch_input.zig         # Input fetching logic
│   └── fetch_inputs_main.zig   # Input fetching CLI
├── input/
│   └── 2025/
│       ├── day01.txt           # Real input (auto-fetched)
│       ├── day01_example.txt   # Example input (manually added)
│       └── ...
└── README.md
```

## Creating Solutions

Day files are automatically created with a template when you first run a day. The template includes:

```zig
const std = @import("std");

var buf1: [2048]u8 = undefined;

pub fn part1(input: []const u8) ![]const u8 {
    // Your solution here
    return "not implemented";
}

pub fn part2(input: []const u8) ![]const u8 {
    // Your solution here
    return "not implemented";
}
```

Both `part1` and `part2` functions must return a string (`[]const u8`). Use a static buffer like `buf1` to format results:

```zig
return std.fmt.bufPrint(&buf1, "{d}", .{result}) catch "error";
```

## Example Output

```
Input file already exists: input/2025/day01.txt
[1/1 example] 11 (15000ns)
[1/1 input] 2904518 (85000ns)
[1/2 example] 31 (12000ns)
[1/2 input] 18650129 (120000ns)
```

- Green text: example input results
- Red text: real input results
- Timing: execution time in nanoseconds
