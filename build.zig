const std = @import("std");
const glfw = @import("mach_glfw");

pub fn linkTracy(b: *std.Build, step: *std.Build.Step.Compile, opt_path: ?[]const u8) void {
    const step_options = b.addOptions();
    step_options.addOption(bool, "tracy_enabled", opt_path != null);
    step.root_module.addOptions("build_options", step_options);

    if (opt_path) |path| {
        step.addIncludePath(b.path(path));
        const tracy_client_source_path = std.fs.path.join(step.step.owner.allocator, &.{ path, "TracyClient.cpp" }) catch unreachable;
        step.addCSourceFile(.{
            .file = b.path(tracy_client_source_path),
            .flags = &[_][]const u8{
                "-DTRACY_ENABLE",
                "-DTRACY_FIBERS",
                // MinGW doesn't have all the newfangled windows features,
                // so we need to pretend to have an older windows version.
                "-D_WIN32_WINNT=0x601",
                "-fno-sanitize=undefined",
            },
        });
        step.linkLibC();
        step.linkSystemLibrary("c++");

        if (step.rootModuleTarget().os.tag == .windows) {
            step.linkSystemLibrary("Advapi32");
            step.linkSystemLibrary("User32");
            step.linkSystemLibrary("Ws2_32");
            step.linkSystemLibrary("DbgHelp");
        }
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_tracy = b.option(bool, "tracy", "Build the game with Tracy support") orelse (optimize == .Debug);

    const exe = b.addExecutable(.{
        .name = "stella-dei",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.strip = optimize == .ReleaseFast or optimize == .ReleaseSmall;
    exe.linkLibC();
    if (optimize != .Debug) exe.subsystem = .Windows;
    linkTracy(b, exe, if (use_tracy) "deps/tracy-0.8.2/" else null);

    // Modules
    const gl = b.createModule(.{
        .root_source_file = b.path("deps/gl3v3.zig"),
    });
    exe.root_module.addImport("gl", gl);

    const nanovg = b.createModule(.{
        .root_source_file = b.path("deps/nanovg/src/nanovg.zig"),
    });
    exe.root_module.addImport("nanovg", nanovg);
    const nanovg_c_flags = &.{ "-DFONS_NO_STDIO", "-DSTBI_NO_STDIO", "-fno-stack-protector", "-fno-sanitize=undefined" };
    nanovg.addIncludePath(b.path("deps/nanovg/src"));
    nanovg.addCSourceFiles(.{
        .files = &.{
            "deps/nanovg/src/fontstash.c",
            "deps/nanovg/src/stb_image.c",
        },
        .flags = nanovg_c_flags,
    });

    const zalgebra_dep = b.dependency("zalgebra", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zalgebra", zalgebra_dep.module("zalgebra"));

    const zigimg_dep = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zigimg", zigimg_dep.module("zigimg"));

    const glfw_dep = b.dependency("mach_glfw", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("glfw", glfw_dep.module("mach-glfw"));

    exe.addIncludePath(b.path("deps"));
    exe.addCSourceFile(.{
        .file = b.path("deps/miniaudio.c"),
        .flags = &.{
            "-fno-sanitize=undefined", // disable UBSAN (due to false positives)
        },
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
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_tests.linkLibC();
    exe_tests.root_module.addImport("nanovg", nanovg);
    exe_tests.root_module.addImport("glfw", glfw_dep.module("mach-glfw"));
    exe_tests.root_module.addImport("gl", gl);
    exe_tests.root_module.addImport("zigimg", zigimg_dep.module("zigimg"));
    exe_tests.root_module.addImport("zalgebra", zalgebra_dep.module("zalgebra"));
    exe_tests.addIncludePath(b.path("deps/nanovg/src"));
    exe_tests.addCSourceFile(.{ .file = b.path("deps/nanovg/src/fontstash.c"), .flags = nanovg_c_flags });
    exe_tests.addCSourceFile(.{ .file = b.path("deps/nanovg/src/stb_image.c"), .flags = nanovg_c_flags });
    exe_tests.addIncludePath(b.path("deps"));

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
