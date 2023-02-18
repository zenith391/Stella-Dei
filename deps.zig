// zig fmt: off
const std = @import("std");
const builtin = @import("builtin");
const Pkg = std.build.Pkg;
const string = []const u8;

pub const cache = ".zigmod/deps";

pub fn addAllTo(exe: *std.build.LibExeObjStep) void {
    checkMinZig(builtin.zig_version, exe);
    @setEvalBranchQuota(1_000_000);
    for (packages) |pkg| {
        exe.addPackage(pkg.pkg.?);
    }
    var llc = false;
    var vcpkg = false;
    inline for (comptime std.meta.declarations(package_data)) |decl| {
        const pkg = @as(Package, @field(package_data, decl.name));
        for (pkg.system_libs) |item| {
            exe.linkSystemLibrary(item);
            llc = true;
        }
        for (pkg.frameworks) |item| {
            if (!std.Target.current.isDarwin()) @panic(exe.builder.fmt("a dependency is attempting to link to the framework {s}, which is only possible under Darwin", .{item}));
            exe.linkFramework(item);
            llc = true;
        }
        inline for (pkg.c_include_dirs) |item| {
            exe.addIncludePath(@field(dirs, decl.name) ++ "/" ++ item);
            llc = true;
        }
        inline for (pkg.c_source_files) |item| {
            exe.addCSourceFile(@field(dirs, decl.name) ++ "/" ++ item, pkg.c_source_flags);
            llc = true;
        }
        vcpkg = vcpkg or pkg.vcpkg;
    }
    if (llc) exe.linkLibC();
    if (builtin.os.tag == .windows and vcpkg) exe.addVcpkgPaths(.static) catch |err| @panic(@errorName(err));
}

pub const Package = struct {
    directory: string,
    pkg: ?Pkg = null,
    c_include_dirs: []const string = &.{},
    c_source_files: []const string = &.{},
    c_source_flags: []const string = &.{},
    system_libs: []const string = &.{},
    frameworks: []const string = &.{},
    vcpkg: bool = false,
};

fn checkMinZig(current: std.SemanticVersion, exe: *std.build.LibExeObjStep) void {
    const min = std.SemanticVersion.parse("0.10.0-dev.2220+802f22073") catch return;
    if (current.order(min).compare(.lt)) @panic(exe.builder.fmt("Your Zig version v{} does not meet the minimum build requirement of v{}", .{current, min}));
}

pub const dirs = struct {
    pub const _root = "";
    pub const _93jjp4rc0htn = cache ++ "/../..";
    pub const _eeikd2bttuwz = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _ebanpwiicvn6 = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _thisisnanovg = cache ++ "/../..";
    pub const _u90k1sgk3yt4 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _02bue7ftqpwa = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _7wk4g66tbz6y = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _eeikd2bttuwz = Package{
        .directory = dirs._eeikd2bttuwz,
        .pkg = Pkg{ .name = "zalgebra", .source = .{ .path = dirs._eeikd2bttuwz ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .source = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _ebanpwiicvn6 = Package{
        .directory = dirs._ebanpwiicvn6,
        .pkg = Pkg{ .name = "glfw", .source = .{ .path = dirs._ebanpwiicvn6 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _thisisnanovg = Package{
        .directory = dirs._thisisnanovg,
        .pkg = Pkg{ .name = "nanovg", .source = .{ .path = dirs._thisisnanovg ++ "/deps/nanovg/src/nanovg.zig" }, .dependencies = null },
        .c_include_dirs = &.{ "deps/nanovg/src" },
        .c_source_files = &.{ "deps/nanovg/src/fontstash.c", "deps/nanovg/src/stb_image.c" },
        .c_source_flags = &.{ "-DFONS_NO_STDIO", "-DSTBI_NO_STDIO", "-fno-stack-protector", "-fno-sanitize=undefined" },
    };
    pub const _u90k1sgk3yt4 = Package{
        .directory = dirs._u90k1sgk3yt4,
        .pkg = Pkg{ .name = "zalgebra", .source = .{ .path = dirs._u90k1sgk3yt4 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _02bue7ftqpwa = Package{
        .directory = dirs._02bue7ftqpwa,
        .pkg = Pkg{ .name = "glfw", .source = .{ .path = dirs._02bue7ftqpwa ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _7wk4g66tbz6y = Package{
        .directory = dirs._7wk4g66tbz6y,
        .pkg = Pkg{ .name = "build-glfw", .source = .{ .path = dirs._7wk4g66tbz6y ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "c", },
    };
};

pub const packages = &[_]Package{
    package_data._eeikd2bttuwz,
    package_data._3hmo0glo2xj9,
    package_data._ebanpwiicvn6,
    package_data._thisisnanovg,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._eeikd2bttuwz;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const glfw = package_data._ebanpwiicvn6;
    pub const nanovg = package_data._thisisnanovg;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const nanovg = @import(".zigmod/deps/../../deps/nanovg/src/nanovg.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
