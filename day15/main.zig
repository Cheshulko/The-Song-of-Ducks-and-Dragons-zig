const std = @import("std");

fn abs(x: i32) i32 {
    return if (x < 0) -x else x;
}

const Turn = union(enum) {
    Right,
    Left,
};

const Move = struct {
    turn: Turn,
    len: usize,
};

pub fn Point(T: type) type {
    return struct {
        i: T,
        j: T,

        pub fn add(self: *const @This(), other: @This()) @This() {
            return @This(){
                .i = self.i + other.i,
                .j = self.j + other.j,
            };
        }
    };
}

const Direction = union(enum) {
    Up,
    Right,
    Down,
    Left,

    fn get_step(self: *const Direction) Point(i32) {
        return switch (self.*) {
            .Up => |_| Point(i32){ .i = -1, .j = 0 },
            .Right => |_| Point(i32){ .i = 0, .j = 1 },
            .Down => |_| Point(i32){ .i = 1, .j = 0 },
            .Left => |_| Point(i32){ .i = 0, .j = -1 },
        };
    }

    fn apply(self: *const Direction, turn: Turn) Direction {
        return switch (turn) {
            .Left => switch (self.*) {
                .Up => .Left,
                .Right => .Up,
                .Down => .Right,
                .Left => .Down,
            },
            .Right => switch (self.*) {
                .Up => .Right,
                .Right => .Down,
                .Down => .Left,
                .Left => .Up,
            },
        };
    }
};

const Position = struct {
    point: Point(i32),
    direction: Direction,

    pub fn apply(self: *const @This(), move: Move) @This() {
        const direction_to = self.direction.apply(move.turn);
        const step = direction_to.get_step();
        const dp = Point(i32){
            .i = step.i * @as(i32, @intCast(move.len)),
            .j = step.j * @as(i32, @intCast(move.len)),
        };

        return Position{
            .point = self.point.add(dp),
            .direction = direction_to,
        };
    }
};

pub fn Compressed(T: type) type {
    return struct {
        sorted: std.ArrayList(T),
        compressed: std.AutoHashMap(T, usize),

        pub fn init(allocator: std.mem.Allocator, original: std.ArrayList(T), comparator: fn (void, T, T) bool) !Compressed(T) {
            var unique = std.AutoHashMap(T, void).init(allocator);
            defer unique.deinit();

            for (original.items) |item| {
                try unique.put(item - 1, {});
                try unique.put(item, {});
                try unique.put(item + 1, {});
            }

            var sorted: std.ArrayList(T) = .empty;
            var it = unique.iterator();
            while (it.next()) |entry| {
                try sorted.append(allocator, entry.key_ptr.*);
            }
            std.sort.block(T, sorted.items, {}, comparator);

            var compressed = std.AutoHashMap(T, usize).init(allocator);
            for (sorted.items) |value| {
                const s: usize = @intCast(compressed.count());
                try compressed.put(value, s);
            }

            return Compressed(T){
                .sorted = sorted,
                .compressed = compressed,
            };
        }

        pub fn get_compressed(self: *const Compressed(T), item: T) ?usize {
            return self.compressed.get(item);
        }

        pub fn get_origin(self: *const Compressed(T), ind: usize) ?T {
            if (ind >= self.sorted.items.len) return null;

            return self.sorted.items[ind];
        }

        pub fn size(self: *const Compressed(T)) usize {
            return self.sorted.items.len;
        }

        pub fn deinit(self: *Compressed(T), allocator: std.mem.Allocator) void {
            self.sorted.deinit(allocator);
            self.compressed.deinit();
        }
    };
}

const Moves_I = [_]i32{ 0, -1, 0, 1 };
const Moves_J = [_]i32{ -1, 0, 1, 0 };

const Maze = struct {
    grid: std.ArrayList(std.ArrayList(i32)),
    compressed_i: Compressed(i32),
    compressed_j: Compressed(i32),
    start: Point(usize),
    end: Point(usize),

    pub fn rows(self: *const Maze) usize {
        return self.grid.items.len;
    }

    pub fn cols(self: *const Maze) usize {
        std.debug.assert(self.grid.items.len > 0);

        return self.grid.items[0].items.len;
    }

    pub fn is_valid(self: *const Maze, p: Point(usize)) bool {
        return p.i >= 0 and p.i < self.rows() and p.j >= 0 and p.j < self.cols();
    }

    pub fn build_from_moves(
        allocator: std.mem.Allocator,
        moves: std.ArrayList(Move),
    ) !Maze {
        var wall_i: std.ArrayList(i32) = .empty;
        defer wall_i.deinit(allocator);

        var wall_j: std.ArrayList(i32) = .empty;
        defer wall_j.deinit(allocator);

        {
            var position = Position{
                .direction = .Up,
                .point = Point(i32){ .i = 0, .j = 0 },
            };
            try wall_i.append(allocator, position.point.i);
            try wall_j.append(allocator, position.point.j);

            for (moves.items) |move| {
                position = position.apply(move);

                try wall_i.append(allocator, position.point.i);
                try wall_j.append(allocator, position.point.j);
            }
        }

        const compressed_i = try Compressed(i32).init(allocator, wall_i, comptime std.sort.asc(i32));
        const compressed_j = try Compressed(i32).init(allocator, wall_j, comptime std.sort.asc(i32));

        const n = compressed_i.size();
        const m = compressed_j.size();

        var grid: std.ArrayList(std.ArrayList(i32)) = .empty;
        for (0..n) |_| {
            var row: std.ArrayList(i32) = .empty;
            try row.resize(allocator, m);
            @memset(row.items, 0);

            try grid.append(allocator, row);
        }

        var position = Position{
            .direction = .Up,
            .point = Point(i32){ .i = 0, .j = 0 },
        };

        for (moves.items) |move| {
            const to = position.apply(move);

            const i_1 = compressed_i.get_compressed(position.point.i).?;
            const j_1 = compressed_j.get_compressed(position.point.j).?;

            const i_2 = compressed_i.get_compressed(to.point.i).?;
            const j_2 = compressed_j.get_compressed(to.point.j).?;

            const mi_i = @min(i_1, i_2);
            const ma_i = @max(i_1, i_2);
            const mi_j = @min(j_1, j_2);
            const ma_j = @max(j_1, j_2);

            for (mi_i..(ma_i + 1)) |i| {
                for (mi_j..(ma_j + 1)) |j| {
                    grid.items[i].items[j] = -1;
                }
            }

            position = to;
        }

        const i_start = compressed_i.get_compressed(0).?;
        const j_start = compressed_j.get_compressed(0).?;
        grid.items[i_start].items[j_start] = 1;

        const i_end = compressed_i.get_compressed(position.point.i).?;
        const j_end = compressed_j.get_compressed(position.point.j).?;
        grid.items[i_end].items[j_end] = 0;

        return Maze{
            .start = Point(usize){ .i = i_start, .j = j_start },
            .end = Point(usize){ .i = i_end, .j = j_end },
            .grid = grid,
            .compressed_i = compressed_i,
            .compressed_j = compressed_j,
        };
    }

    pub fn add_dij(point: Point(usize), di: i32, dj: i32) ?Point(usize) {
        const i_: i32 = @intCast(point.i);
        const j_: i32 = @intCast(point.j);

        if (i_ + di >= 0 and j_ + dj >= 0) {
            return Point(usize){
                .i = @intCast(i_ + di),
                .j = @intCast(j_ + dj),
            };
        }

        return null;
    }

    pub fn solve(self: Maze, allocator: std.mem.Allocator) !i32 {
        var q: std.Deque(Point(usize)) = .empty;
        defer q.deinit(allocator);

        try q.pushBack(allocator, self.start);

        while (q.len > 0) {
            const cur = q.popFront().?;
            const d = self.grid.items[cur.i].items[cur.j];

            for (Moves_I, Moves_J) |di, dj| {
                const p_to = Maze.add_dij(cur, di, dj) orelse continue;
                if (!self.is_valid(p_to)) continue;

                if (self.grid.items[p_to.i].items[p_to.j] == 0) {
                    const delta_i = self.compressed_i.get_origin(cur.i).? - self.compressed_i.get_origin(p_to.i).?;
                    const delta_j = self.compressed_j.get_origin(cur.j).? - self.compressed_j.get_origin(p_to.j).?;

                    self.grid.items[p_to.i].items[p_to.j] = d + abs(delta_i) + abs(delta_j);

                    try q.pushBack(allocator, p_to);
                }
            }
        }

        return self.grid.items[self.end.i].items[self.end.j] - 1;
    }

    pub fn deinit(self: *Maze, allocator: std.mem.Allocator) void {
        while (self.grid.items.len > 0) {
            var inner = self.grid.pop().?;
            inner.deinit(allocator);
        }
        self.grid.deinit(allocator);
        self.compressed_i.deinit(allocator);
        self.compressed_j.deinit(allocator);
    }
};

const Input = struct {
    file_content: []const u8,
    maze: Maze,

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

        var moves: std.ArrayList(Move) = .empty;
        defer moves.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, ',');
        while (it.next()) |row_str| {
            const t = row_str[0];
            const v = try std.fmt.parseInt(usize, row_str[1..], 10);

            try moves.append(allocator, switch (t) {
                'R' => Move{ .turn = .Right, .len = v },
                'L' => Move{ .turn = .Left, .len = v },
                else => unreachable,
            });
        }

        return Input{
            .file_content = file_content,
            .maze = try Maze.build_from_moves(allocator, moves),
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.maze.deinit(allocator);
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
        2 => solve_1(allocator, input),
        3 => solve_1(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const answer = try input.maze.solve(allocator);
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day15/input/input_1_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "6";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day15/input/input_1_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "16";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day15/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "101";
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
        var input = try Input.parse(allocator, "day15/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "3861";
        const answer = try solve_1(allocator, input);
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
        var input = try Input.parse(allocator, "day15/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "463760016";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
