const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const days = [_][]const u8{
        "day01",
        "day02",
        "day03",
        "day04",
        "day05",
    };

    var exes = std.StringHashMap(*std.Build.Step.Compile).init(b.allocator);

    for (days) |day| {
        const day_module = b.createModule(.{
            .root_source_file = b.path(b.pathJoin(&.{ day, "main.zig" })),
            .target = target,
            .optimize = optimize,
        });

        const exe = b.addExecutable(.{
            .name = day,
            .root_module = day_module,
        });

        b.installArtifact(exe);
        _ = exes.put(day, exe) catch unreachable;
    }

    const day_arg = b.option([]const u8, "day", "Which day to run") orelse "";
    const part_arg = b.option([]const u8, "part", "Which part to run") orelse "";
    const input_arg = b.option([]const u8, "input", "Path to input file") orelse "";

    const exe = exes.get(day_arg) orelse null;
    const run_step = b.step("run", "Run selected day");

    if (day_arg.len == 0 or part_arg.len == 0 or input_arg.len == 0 or exe == null) {
        if (day_arg.len > 0 and exe == null)
            std.debug.print("Unknown day: {s}\n\n", .{day_arg});

        std.debug.print("Usage:\n", .{});
        std.debug.print(
            "  zig build -Dday=<day> -Dpart=<part> -Dinput=<input_file> run\n\n",
            .{},
        );
        std.debug.print("Example:\n", .{});
        std.debug.print(
            "  zig build -Dday=day01 -Dpart=1 -Dinput=day01/input/input_1.txt run\n\n",
            .{},
        );
        std.debug.print("Available days:\n", .{});
        for (days) |d| std.debug.print("  {s}\n", .{d});

        return;
    }

    const run_cmd = b.addRunArtifact(exe.?);
    run_cmd.addArg(part_arg);
    run_cmd.addArg(input_arg);

    run_step.dependOn(&run_cmd.step);
    b.default_step.dependOn(run_step);
}
