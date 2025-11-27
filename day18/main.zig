const std = @import("std");

const Connection = struct {
    to: ?usize,
    thickness: i64,
};

const Case = std.ArrayList(i64);
const Cases = std.ArrayList(Case);

const Graph = struct {
    plant_thicknesses: std.ArrayList(i64),
    connections: std.ArrayList(std.ArrayList(Connection)),

    pub fn init(
        plant_thicknesses: std.ArrayList(i64),
        connections: std.ArrayList(std.ArrayList(Connection)),
    ) Graph {
        return Graph{
            .plant_thicknesses = plant_thicknesses,
            .connections = connections,
        };
    }

    pub fn plants(self: *const Graph) usize {
        return self.connections.items.len;
    }

    fn dfs(self: *const Graph, case: ?*const Case, cur: usize) i64 {
        var in: i64 = 0;
        for (self.connections.items[cur].items) |to_con| {
            if (to_con.to) |to| {
                const to_in = self.dfs(case, to);

                in += to_in * to_con.thickness;
            } else {
                in += to_con.thickness;
            }
        }

        if (in >= self.plant_thicknesses.items[cur]) {
            if (case) |case_states| {
                if (cur < case_states.items.len) {
                    in *= case_states.items[cur];
                }
            }

            return in;
        } else {
            return 0;
        }
    }

    pub fn deinit(self: *Graph, allocator: std.mem.Allocator) void {
        while (self.connections.items.len > 0) {
            var inner = self.connections.pop().?;
            inner.deinit(allocator);
        }
        self.connections.deinit(allocator);
        self.plant_thicknesses.deinit(allocator);
    }
};

const Input = struct {
    file_content: []const u8,
    graph: Graph,
    cases: ?Cases,

    pub fn parse(allocator: std.mem.Allocator, file_path: []const u8) !Input {
        return Input.init(allocator, file_path);
    }

    fn take_last(content: []const u8) []const u8 {
        var last: []const u8 = "";
        var plant_str_it = std.mem.splitScalar(u8, content, ' ');
        while (plant_str_it.next()) |next| {
            last = next;
        }

        return last;
    }

    fn parse_graph(allocator: std.mem.Allocator, input: []const u8) !Graph {
        var connections: std.ArrayList(std.ArrayList(Connection)) = .empty;
        errdefer connections.deinit(allocator);

        var plant_thicknesses: std.ArrayList(i64) = .empty;
        errdefer plant_thicknesses.deinit(allocator);

        var it = std.mem.splitSequence(u8, input, "\n\n");
        while (it.next()) |plant| {
            var plant_connections: std.ArrayList(Connection) = .empty;
            errdefer plant_connections.deinit(allocator);

            var plant_it = std.mem.splitScalar(u8, plant, '\n');

            {
                const thickness_str = Input.take_last(plant_it.next().?);
                const thickness = try std.fmt.parseInt(i64, thickness_str[0 .. thickness_str.len - 1], 10);
                try plant_thicknesses.append(allocator, thickness);
            }

            {
                while (plant_it.next()) |conntextion_str| {
                    var connection = Connection{
                        .thickness = 0,
                        .to = null,
                    };

                    var conntextion_str_it = std.mem.splitScalar(u8, conntextion_str, ' ');
                    _ = conntextion_str_it.next().?;

                    const t = conntextion_str_it.next().?;

                    if (std.mem.eql(u8, t, "branch")) {
                        _ = conntextion_str_it.next().?;
                        _ = conntextion_str_it.next().?;
                        const to = conntextion_str_it.next().?;
                        connection.to = try std.fmt.parseInt(usize, to, 10) - 1;
                    }

                    const thickness_str = Input.take_last(conntextion_str);
                    const thickness = try std.fmt.parseInt(i64, thickness_str, 10);
                    connection.thickness = thickness;

                    try plant_connections.append(allocator, connection);
                }
            }

            try connections.append(allocator, plant_connections);
        }

        return Graph.init(plant_thicknesses, connections);
    }

    fn parse_cases(allocator: std.mem.Allocator, input: []const u8) !Cases {
        var cases: Cases = .empty;
        errdefer cases.deinit(allocator);

        var it = std.mem.splitScalar(u8, input, '\n');
        while (it.next()) |case_str| {
            var case: std.ArrayList(i64) = .empty;
            errdefer case.deinit(allocator);

            var case_it = std.mem.splitScalar(u8, case_str, ' ');
            while (case_it.next()) |num_str| {
                try case.append(allocator, try std.fmt.parseInt(i64, num_str, 10));
            }

            try cases.append(allocator, case);
        }

        return cases;
    }

    fn init(allocator: std.mem.Allocator, file_path: []const u8) !Input {
        const file_content = try std.fs.cwd().readFileAlloc(
            file_path,
            allocator,
            .unlimited,
        );
        errdefer allocator.free(file_content);

        var it = std.mem.splitSequence(u8, file_content, "\n\n\n");

        const graph = try parse_graph(allocator, it.next().?);

        var cases: ?Cases = null;
        if (it.next()) |cases_str| {
            cases = try parse_cases(allocator, cases_str);
        }

        return Input{
            .file_content = file_content,
            .graph = graph,
            .cases = cases,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.graph.deinit(allocator);
        if (self.cases) |*cases| {
            while (cases.items.len > 0) {
                var inner = cases.pop().?;
                inner.deinit(allocator);
            }
            cases.deinit(allocator);
        }
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
    const n = input.graph.plants();
    const last = n - 1;

    const answer = input.graph.dfs(null, last);
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.graph.plants();
    const last = n - 1;

    var answer: i64 = 0;
    for (input.cases.?.items) |*case| {
        answer += input.graph.dfs(case, last);
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.graph.plants();
    const last = n - 1;

    const best = 10680;

    var answer: i64 = 0;
    for (input.cases.?.items) |*case| {
        const result = input.graph.dfs(case, last);
        if (result > 0) {
            answer += best - result;
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day18/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "774";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }

    {
        var input = try Input.parse(allocator, "day18/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "1713879";
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
        var input = try Input.parse(allocator, "day18/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "324";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day18/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "12695958148";
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
        var input = try Input.parse(allocator, "day18/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "158493";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
