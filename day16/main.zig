const std = @import("std");

const Input = struct {
    file_content: []const u8,
    numbers: std.ArrayList(u64),

    pub fn parse(allocator: std.mem.Allocator, file_path: []const u8) !Input {
        return Input.init(allocator, file_path);
    }

    fn init(allocator: std.mem.Allocator, file_path: []const u8) !Input {
        const file_content = try std.fs.cwd().readFileAlloc(
            file_path,
            allocator,
            .unlimited,
        );
        errdefer allocator.free(file_content);

        var numbers: std.ArrayList(u64) = .empty;
        errdefer numbers.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, ',');
        while (it.next()) |number_str| {
            try numbers.append(allocator, try std.fmt.parseInt(u64, number_str, 10));
        }

        return Input{
            .file_content = file_content,
            .numbers = numbers,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.numbers.deinit(allocator);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        @panic("Wrong input. I do not care .. Use `help`");
    }

    const part = try std.fmt.parseInt(u8, args[1], 10);
    const file_path = args[2];
    std.debug.print("- Running part {} ...\n", .{part});
    std.debug.print("- Input file: {s}\n", .{file_path});

    var input = try Input.parse(allocator, file_path);
    defer input.deinit(allocator);

    const answer = try switch (part) {
        1 => solve_1(allocator, input, 90),
        2 => solve_2(allocator, input),
        3 => solve_3(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn build_columns(
    allocator: std.mem.Allocator,
    numbers: *const std.ArrayList(u64),
) !std.ArrayList(u64) {
    var columns: std.ArrayList(u64) = .empty;

    for (numbers.items, 1..) |num_const, i| {
        var num = num_const;
        for (columns.items) |col| {
            if (@rem(i, col) == 0) {
                num -= 1;
            }
        }

        while (num > 0) : (num -= 1) {
            try columns.append(allocator, i);
        }
    }

    return columns;
}

fn solve_1(allocator: std.mem.Allocator, input: Input, wall: u64) ![]const u8 {
    var answer: u64 = 0;
    for (input.numbers.items) |num| {
        answer += @divFloor(wall, num);
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var columns = try build_columns(allocator, &input.numbers);
    defer columns.deinit(allocator);

    var answer: u64 = 1;
    for (columns.items) |col| {
        answer *= col;
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn can(columns: *const std.ArrayList(u64), blocks: u64, len: u64) bool {
    var blocks_mut = blocks;

    for (columns.items) |col| {
        const need = @divFloor(len, col);
        if (blocks_mut < need) return false;

        blocks_mut -= need;
    }

    return true;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const blocks: u64 = 202520252025000;

    var columns = try build_columns(allocator, &input.numbers);
    defer columns.deinit(allocator);

    var l: u64 = 0;
    var r: u64 = blocks + 1;
    while (r - l > 1) {
        const m = (l + r) >> 1;

        if (can(&columns, blocks, m)) {
            l = m;
        } else {
            r = m;
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{l});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day16/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "193";
        const answer = try solve_1(allocator, input, 90);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }

    {
        var input = try Input.parse(allocator, "day16/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "237";
        const answer = try solve_1(allocator, input, 90);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}

test "Part 2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day16/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "270";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day16/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "113001090048";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}

test "Part 3" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day16/input/input_3_sample.txt");
        defer input.deinit(allocator);

        const expected = "94439495762954";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day16/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "96145580726375";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
