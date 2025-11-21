const std = @import("std");

const Point = struct {
    i: usize,
    j: usize,

    pub fn add_dij(self: *const Point, di: i32, dj: i32) ?Point {
        const i_: i32 = @intCast(self.i);
        const j_: i32 = @intCast(self.j);

        if (i_ + di >= 0 and j_ + dj >= 0) {
            return Point{
                .i = @intCast(i_ + di),
                .j = @intCast(j_ + dj),
            };
        }

        return null;
    }
};

const Moves_Diag_I = [_]i32{ -1, -1, 1, 1 };
const Moves_Diag_J = [_]i32{ -1, 1, -1, 1 };

fn deepCopyNested(
    allocator: std.mem.Allocator,
    src: *const std.ArrayList(std.ArrayList(usize)),
) !std.ArrayList(std.ArrayList(usize)) {
    var dst: std.ArrayList(std.ArrayList(usize)) = .empty;

    for (0..src.items.len) |i| {
        const inner_src = src.items[i];

        var inner_dst: std.ArrayList(usize) = .empty;
        for (0..inner_src.items.len) |j| {
            try inner_dst.append(allocator, inner_src.items[j]);
        }

        try dst.append(allocator, inner_dst);
    }

    return dst;
}

fn hashNested(outer: []const std.ArrayList(usize)) u64 {
    var hasher = std.hash.Fnv1a_64.init();

    const outer_len_bytes = @as([*]const u8, @ptrCast(&outer.len));
    hasher.update(outer_len_bytes[0..@sizeOf(usize)]);

    for (outer) |inner| {
        const inner_len_bytes = @as([*]const u8, @ptrCast(&inner.items.len));
        hasher.update(inner_len_bytes[0..@sizeOf(usize)]);

        if (inner.items.len > 0) {
            const bytes = @as([*]const u8, @ptrCast(inner.items.ptr))[0 .. inner.items.len * @sizeOf(usize)];
            hasher.update(bytes);
        }
    }

    return hasher.final();
}

const Grid = struct {
    grid: std.ArrayList(std.ArrayList(usize)),
    ngrid: std.ArrayList(std.ArrayList(usize)),

    pub fn init(allocator: std.mem.Allocator, grid: std.ArrayList(std.ArrayList(usize))) !Grid {
        const ngrid = try deepCopyNested(allocator, &grid);

        return Grid{
            .grid = grid,
            .ngrid = ngrid,
        };
    }

    pub fn rows(self: *const Grid) usize {
        return self.grid.items.len;
    }

    pub fn cols(self: *const Grid) usize {
        std.debug.assert(self.grid.items.len > 0);

        return self.grid.items[0].items.len;
    }

    pub fn is_valid(self: *const Grid, p: Point) bool {
        return p.i >= 0 and p.i < self.rows() and p.j >= 0 and p.j < self.cols();
    }

    pub fn get(self: *const Grid, p: Point) usize {
        std.debug.assert(self.is_valid(p));

        return self.grid.items[p.i].items[p.j];
    }

    pub fn active_tiles_count(self: *const Grid) usize {
        var sum: usize = 0;
        for (self.grid.items) |*row| {
            for (row.items) |c| {
                sum += c;
            }
        }

        return sum;
    }

    pub fn play_round(self: *Grid) void {
        const n = self.rows();
        const m = self.cols();

        for (0..n) |i| {
            for (0..m) |j| {
                const p = Point{ .i = i, .j = j };

                var active_parity: usize = 0;
                for (Moves_Diag_I, Moves_Diag_J) |di, dj| {
                    if (p.add_dij(di, dj)) |p_to| {
                        if (!self.is_valid(p_to)) continue;

                        active_parity ^= self.get(p_to);
                    }
                }

                // 1. If a tile is active, it will remain active in the next round
                //    if the number of active diagonal neighbours is odd.
                //    Otherwise, it becomes inactive.
                // 2. If a tile is inactive, it will become active in the next round
                //    if the number of active diagonal neighbours is even.
                //    Otherwise, it remains inactive.
                self.ngrid.items[p.i].items[p.j] = self.get(p) ^ active_parity ^ 1;
            }
        }

        std.mem.swap(@TypeOf(self.grid), &self.grid, &self.ngrid);
    }

    pub fn is_match_pattern(self: *const Grid, pattern: *const Grid) bool {
        const n = self.rows();
        const m = self.cols();

        const np = pattern.rows();
        const mp = pattern.cols();

        std.debug.assert(@rem(n - np, 2) == 0);
        const dn = (n - np) / 2;

        std.debug.assert(@rem(m - mp, 2) == 0);
        const dm = (m - mp) / 2;

        for (0..np) |di| {
            const i = dn + di;
            for (0..mp) |dj| {
                const j = dm + dj;
                const p_self = Point{ .i = i, .j = j };
                const p_pattern = Point{ .i = di, .j = dj };

                if (self.get(p_self) != pattern.get(p_pattern)) {
                    return false;
                }
            }
        }

        return true;
    }

    pub fn deinit(self: *Grid, allocator: std.mem.Allocator) void {
        while (self.grid.items.len > 0) {
            var inner = self.grid.pop().?;
            inner.deinit(allocator);
        }
        self.grid.deinit(allocator);

        while (self.ngrid.items.len > 0) {
            var inner = self.ngrid.pop().?;
            inner.deinit(allocator);
        }
        self.ngrid.deinit(allocator);
    }
};

const Input = struct {
    file_content: []const u8,
    grid: Grid,

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

        var grid: std.ArrayList(std.ArrayList(usize)) = .empty;
        errdefer grid.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |row_str| {
            var row: std.ArrayList(usize) = .empty;
            errdefer row.deinit(allocator);

            for (row_str) |c| {
                try row.append(allocator, if (c == '#') 1 else 0);
            }

            try grid.append(allocator, row);
        }

        return Input{
            .file_content = file_content,
            .grid = try Grid.init(allocator, grid),
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.grid.deinit(allocator);
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
        1 => solve_1(allocator, input, 10),
        2 => solve_1(allocator, input, 2025),
        3 => solve_3(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input, rounds: usize) ![]const u8 {
    var input_mut = input;
    const grid = &input_mut.grid;

    var answer: usize = 0;
    for (0..rounds) |_| {
        grid.play_round();
        answer += grid.active_tiles_count();
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const R: usize = 1000000000;
    const N: usize = 34;

    var grid: std.ArrayList(std.ArrayList(usize)) = .empty;
    errdefer grid.deinit(allocator);
    for (0..N) |_| {
        var row: std.ArrayList(usize) = .empty;
        try row.resize(allocator, N);
        @memset(row.items, 0);

        try grid.append(allocator, row);
    }

    var mainGrid = try Grid.init(allocator, grid);
    defer mainGrid.deinit(allocator);

    var seen = std.AutoHashMap(u64, usize).init(allocator);
    defer seen.deinit();

    var pref: std.ArrayList(usize) = .empty;
    defer pref.deinit(allocator);

    var iter: usize = 0;
    var per_cycle: usize = 0;
    var iter_cycle_start: usize = 0;

    while (true) : (iter += 1) {
        const h = hashNested(mainGrid.grid.items);
        if (seen.get(h)) |seen_on_it| {
            iter_cycle_start = seen_on_it;
            break;
        }
        if (mainGrid.is_match_pattern(&input.grid)) {
            per_cycle += mainGrid.active_tiles_count();
        }
        try pref.append(allocator, per_cycle);
        try seen.put(h, iter);
        mainGrid.play_round();
    }

    iter -= 1;
    per_cycle -= pref.items[iter_cycle_start]; // it is 0 for the test inputes

    var answer: usize = 0;
    answer += @divFloor(R - iter_cycle_start, iter) * per_cycle;

    for (0..@rem(R - iter_cycle_start, iter)) |_| {
        if (mainGrid.is_match_pattern(&input.grid)) {
            answer += mainGrid.active_tiles_count();
        }
        mainGrid.play_round();
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day14/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "200";
        const answer = try solve_1(allocator, input, 10);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day14/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "527";
        const answer = try solve_1(allocator, input, 10);
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
        var input = try Input.parse(allocator, "day14/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "1170185";
        const answer = try solve_1(allocator, input, 2025);
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
        var input = try Input.parse(allocator, "day14/input/input_3_sample.txt");
        defer input.deinit(allocator);

        const expected = "278388552";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day14/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "1027594832";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
