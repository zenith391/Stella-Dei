const std = @import("std");
const deps = @import("deps.zig");
const glfw = deps.imports.build_glfw;

pub fn linkTracy(b: *std.build.Builder, step: *std.build.CompileStep, opt_path: ?[]const u8) void {
    const step_options = b.addOptions();
    step.addOptions("build_options", step_options);
    step_options.addOption(bool, "tracy_enabled", opt_path != null);

    if (opt_path) |path| {
        step.addIncludePath(path);
        const tracy_client_source_path = std.fs.path.join(step.step.owner.allocator, &.{ path, "TracyClient.cpp" }) catch unreachable;
        step.addCSourceFile(tracy_client_source_path, &[_][]const u8{
            "-DTRACY_ENABLE",
            "-DTRACY_FIBERS",
            // MinGW doesn't have all the newfangled windows features,
            // so we need to pretend to have an older windows version.
            "-D_WIN32_WINNT=0x601",
            "-fno-sanitize=undefined",
        });

        step.linkLibC();
        step.linkSystemLibrary("c++");

        if (step.target.isWindows()) {
            step.linkSystemLibrary("Advapi32");
            step.linkSystemLibrary("User32");
            step.linkSystemLibrary("Ws2_32");
            step.linkSystemLibrary("DbgHelp");
        }
    }
}

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_tracy = b.option(bool, "tracy", "Build the game with Tracy support") orelse (optimize == .Debug);

    const exe = b.addExecutable(.{
        .name = "stella-dei",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.strip = optimize == .ReleaseFast or optimize == .ReleaseSmall;
    exe.linkLibC();
    if (optimize != .Debug) exe.subsystem = .Windows;
    linkTracy(b, exe, if (use_tracy) "deps/tracy-0.8.2/" else null);

    // Modules
    const gl = b.createModule(.{
        .source_file = .{ .path = "deps/gl3v3.zig" },
    });
    exe.addModule("gl", gl);

    const nanovg = b.createModule(.{
        .source_file = .{ .path = "deps/nanovg/src/nanovg.zig" },
    });
    exe.addModule("nanovg", nanovg);
    const nanovg_c_flags = &.{ "-DFONS_NO_STDIO", "-DSTBI_NO_STDIO", "-fno-stack-protector", "-fno-sanitize=undefined" };
    exe.addIncludePath("deps/nanovg/src");
    exe.addCSourceFile("deps/nanovg/src/fontstash.c", nanovg_c_flags);
    exe.addCSourceFile("deps/nanovg/src/stb_image.c", nanovg_c_flags);

    const zalgebra = b.createModule(.{
        .source_file = .{ .path = ".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig" },
    });
    exe.addModule("zalgebra", zalgebra);

    const zigimg = b.createModule(.{
        .source_file = .{ .path = ".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig" },
    });
    exe.addModule("zigimg", zigimg);

    // deps.addAllTo(exe);
    try glfw.link(b, exe, .{});
    const glfw_module = glfw.module(b);
    exe.addModule("glfw", glfw_module);

    exe.addIncludePath("deps");
    exe.addCSourceFile("deps/miniaudio.c", &.{
        "-fno-sanitize=undefined", // disable UBSAN (due to false positives)
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    var exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
