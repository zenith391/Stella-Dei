const std  = @import("std");
const deps = @import("deps.zig");
const build_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/build_tracy.zig");
const glfw = deps.imports.build_glfw;

/// Step used to convert from tabs to space
const ConvertStep = struct {
    generated_file: std.build.GeneratedFile,
    step: std.build.Step,
    builder: *std.build.Builder,
    root: []const u8,

    pub fn create(builder: *std.build.Builder, root: []const u8) *ConvertStep {
        const self = builder.allocator.create(ConvertStep) catch unreachable;
        self.* = .{
            .generated_file = undefined,
            .step = std.build.Step.init(.install_file, "convert", builder.allocator, ConvertStep.make),
            .builder = builder,
            .root = root
        };

        self.generated_file = .{ .step = &self.step };
        return self;
    }

    pub fn getSource(self: ConvertStep) std.build.FileSource {
        return .{ .generated = &self.generated_file };
    }

    pub fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(ConvertStep, "step", step);

        var sourceDir = try std.fs.cwd().openDir(std.fs.path.dirname(self.root).?, .{ .iterate = true });
        defer sourceDir.close();

        var cacheRoot = try std.fs.cwd().openDir(self.builder.cache_root, .{});
        defer cacheRoot.close();

        var targetDir = try cacheRoot.makeOpenPath("converted", .{});
        defer targetDir.close();

        var walker = try sourceDir.walk(self.builder.allocator);
        while (try walker.next()) |entry| {
            if (entry.kind == .File) {
                var source = try sourceDir.openFile(entry.path, .{});
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

        self.generated_file.path = try std.mem.concat(self.builder.allocator, u8,
            &[_][]const u8 { self.builder.cache_root, "/converted/main.zig" });
    }
};

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const convert = ConvertStep.create(b, "src/main.zig");

    const exe = b.addExecutableSource("stella-dei", convert.getSource());
    exe.subsystem = .Windows;
    exe.setTarget(target);
    exe.setBuildMode(mode);
    build_tracy.link(b, exe, if ((mode == .Debug or true) and target.isNative()) ".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy-0.7.8/" else null);
    deps.addAllTo(exe);
    glfw.link(b, exe, .{});

    exe.addIncludePath("deps");
    exe.addCSourceFile("deps/nuklear.c", &.{});
    exe.addCSourceFile("deps/miniaudio.c", &.{
        "-fno-sanitize=undefined" // disable UBSAN (due to false positives)
    });
    
    exe.install();

    const run_cmd = exe.run();

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    var exe_tests = b.addTest("src/main.zig");
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
