const std = @import("std");

const Spine = struct {
    value: i32,
    left: ?i32,
    right: ?i32,
    spine_value: i64,

    fn build_level(self: *const Spine, allocator: std.mem.Allocator) !i64 {
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(allocator);

        if (self.left) |left| {
            const s = try std.fmt.allocPrint(allocator, "{}", .{left});
            defer allocator.free(s);

            try buffer.appendSlice(allocator, s);
        }
        {
            const s = try std.fmt.allocPrint(allocator, "{}", .{self.value});
            defer allocator.free(s);

            try buffer.appendSlice(allocator, s);
        }

        if (self.right) |right| {
            const s = try std.fmt.allocPrint(allocator, "{}", .{right});
            defer allocator.free(s);

            try buffer.appendSlice(allocator, s);
        }

        return try std.fmt.parseInt(i64, buffer.items, 10);
    }
};

const Sword = struct {
    id: i32,
    numbers: std.ArrayList(i32),
    spines: std.ArrayList(Spine),
    power: i64,

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Sword {
        return Sword.init(allocator, input);
    }

    fn init(allocator: std.mem.Allocator, input: []const u8) !Sword {
        var numbers: std.ArrayList(i32) = .empty;
        errdefer numbers.deinit(allocator);

        var it = std.mem.splitScalar(u8, input, ':');
        const id = try std.fmt.parseInt(i32, it.next().?, 10);

        const rest = it.next().?;
        var it_rest = std.mem.splitScalar(u8, rest, ',');
        while (it_rest.next()) |line| {
            try numbers.append(allocator, try std.fmt.parseInt(i32, line, 10));
        }

        const spines = try Sword.build(allocator, &numbers);
        const result = try joinInts(allocator, &spines);
        defer allocator.free(result);

        const power = try std.fmt.parseInt(i64, result, 10);

        return Sword{
            .id = id,
            .numbers = numbers,
            .spines = spines,
            .power = power,
        };
    }

    fn build(allocator: std.mem.Allocator, numbers: *const std.ArrayList(i32)) !std.ArrayList(Spine) {
        var spines: std.ArrayList(Spine) = .empty;

        for (numbers.items) |number| {
            var found = false;
            for (spines.items) |*spine| {
                if (number < spine.value and spine.left == null) {
                    found = true;
                    spine.left = number;
                } else if (number > spine.value and spine.right == null) {
                    found = true;
                    spine.right = number;
                }
                if (found) break;
            }

            if (!found) {
                try spines.append(allocator, Spine{
                    .value = number,
                    .left = null,
                    .right = null,
                    .spine_value = 0,
                });
            }
        }

        for (spines.items) |*spine| {
            spine.spine_value = try spine.build_level(allocator);
        }

        return spines;
    }

    pub fn deinit(self: *Sword, allocator: std.mem.Allocator) void {
        self.numbers.deinit(allocator);
        self.spines.deinit(allocator);
    }
};

const Input = struct {
    file_content: []u8,
    swords: std.ArrayList(Sword),

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

        var swords: std.ArrayList(Sword) = .empty;
        errdefer swords.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |line| {
            try swords.append(allocator, try Sword.parse(allocator, line));
        }

        return Input{ .swords = swords, .file_content = file_content };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        for (self.swords.items) |*sword| {
            sword.deinit(allocator);
        }
        self.swords.deinit(allocator);
        allocator.free(self.file_content);
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
        1 => solve_1(allocator, input),
        2 => solve_2(allocator, input),
        3 => solve_3(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const sword = input.swords.items[0];
    const result = try std.fmt.allocPrint(allocator, "{}", .{sword.power});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.swords.items.len;

    var sword_values: std.ArrayList(i64) = .empty;
    defer sword_values.deinit(allocator);

    for (input.swords.items) |*sword| {
        try sword_values.append(allocator, sword.power);
    }

    std.sort.block(i64, sword_values.items, {}, comptime std.sort.asc(i64));
    const result = try std.fmt.allocPrint(
        allocator,
        "{}",
        .{sword_values.items[n - 1] - sword_values.items[0]},
    );

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    std.sort.block(Sword, input.swords.items, {}, swordPowerSort);

    var ans: i64 = 0;
    for (input.swords.items, 1..) |*sword, ind| {
        ans += @as(i32, @intCast(ind)) * sword.id;
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

fn swordPowerSort(_: void, a: Sword, b: Sword) bool {
    if (a.power != b.power) {
        return a.power > b.power;
    }

    const n = a.spines.items.len;
    for (0..n) |i| {
        const numb_a = a.spines.items[i].spine_value;
        const numb_b = b.spines.items[i].spine_value;

        if (numb_a != numb_b) {
            return numb_a > numb_b;
        }
    }

    return a.id > b.id;
}

fn joinInts(allocator: std.mem.Allocator, spines: *const std.ArrayList(Spine)) ![]u8 {
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    for (spines.items) |*spine| {
        const s = try std.fmt.allocPrint(allocator, "{}", .{spine.value});
        defer allocator.free(s);
        try buffer.appendSlice(allocator, s);
    }

    return buffer.toOwnedSlice(allocator);
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day05/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "581078";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day05/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "4542367465";
        const answer = try solve_1(allocator, input);
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
        var input = try Input.parse(allocator, "day05/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "77053";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day05/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "8105742955601";
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
        var input = try Input.parse(allocator, "day05/input/input_3_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "260";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day05/input/input_3_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "4";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day05/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "31453583";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
