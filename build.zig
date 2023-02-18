const std = @import("std");
const deps = @import("deps.zig");
const glfw = deps.imports.build_glfw;

/// Step used to convert from tabs to space
const ConvertStep = struct {
    generated_file: std.build.GeneratedFile,
    step: std.build.Step,
    builder: *std.build.Builder,
    root: []const u8,

    pub fn create(builder: *std.build.Builder, root: []const u8) *ConvertStep {
        const self = builder.allocator.create(ConvertStep) catch unreachable;
        self.* = .{ .generated_file = undefined, .step = std.build.Step.init(.install_file, "convert", builder.allocator, ConvertStep.make), .builder = builder, .root = root };

        self.generated_file = .{ .step = &self.step };
        return self;
    }

    pub fn getSource(self: *const ConvertStep) std.build.FileSource {
        return .{ .generated = &self.generated_file };
    }

    pub fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(ConvertStep, "step", step);

        var sourceDir = try std.fs.cwd().openIterableDir(std.fs.path.dirname(self.root).?, .{});
        defer sourceDir.close();

        var cacheRoot = self.builder.cache_root.handle;

        var targetDir = try cacheRoot.makeOpenPath("converted", .{});
        defer targetDir.close();

        var walker = try sourceDir.walk(self.builder.allocator);
        while (try walker.next()) |entry| {
            if (entry.kind == .File) {
                var source = try sourceDir.dir.openFile(entry.path, .{});
                defer source.close();

                const text = try source.readToEndAlloc(self.builder.allocator, std.math.maxInt(usize));
                defer self.builder.allocator.free(text);

                // Replace every occurence of a tab by a single space
                _ = std.mem.replace(u8, text, "\t", " ", text);

                // Ensure the target file's parent directory exists
                const dirname = std.fs.path.dirname(entry.path) orelse ".";
                try targetDir.makePath(dirname);

                var target = try targetDir.createFile(entry.path, .{});
                defer target.close();
                try target.writeAll(text);
            } else if (entry.kind == .Directory) {
                try targetDir.makePath(entry.path);
            }
        }

        self.generated_file.path = try std.mem.concat(self.builder.allocator, u8, &[_][]const u8{ self.builder.cache_root.path.?, "/converted/main.zig" });
    }
};

pub fn linkTracy(b: *std.build.Builder, step: *std.build.LibExeObjStep, opt_path: ?[]const u8) void {
    const step_options = b.addOptions();
    step.addOptions("build_options", step_options);
    step_options.addOption(bool, "tracy_enabled", opt_path != null);

    if (opt_path) |path| {
        step.addIncludePath(path);
        const tracy_client_source_path = std.fs.path.join(step.builder.allocator, &.{ path, "TracyClient.cpp" }) catch unreachable;
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

    const convert = ConvertStep.create(b, "src/main.zig");

    const exe = b.addExecutable(.{
        .name = "stella-dei",
        .root_source_file = convert.getSource(),
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

    exe.install();

    const run_cmd = exe.run();

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    var exe_tests = b.addTest(.{
        .root_source_file = convert.getSource(),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
