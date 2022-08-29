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
            exe.addIncludeDir(@field(dirs, decl.name) ++ "/" ++ item);
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
    pub const _ry8lll9fuc4y = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _ystjmavfvf6v = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _7ft8dayafs70 = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _rvid0clm032e = cache ++ "/git/github.com/fabioarnold/nanovg-zig";
    pub const _x5su0m0e7yxg = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _2i2jr6xhwjml = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _e1xxnyj4bani = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _fmcf3oheu8gr = cache ++ "/git/github.com/fabioarnold/nanovg-zig";
    pub const _4wijkno7k5j6 = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _ry8lll9fuc4y = Package{
        .directory = dirs._ry8lll9fuc4y,
        .pkg = Pkg{ .name = "zalgebra", .source = .{ .path = dirs._ry8lll9fuc4y ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _ystjmavfvf6v = Package{
        .directory = dirs._ystjmavfvf6v,
        .pkg = Pkg{ .name = "gl", .source = .{ .path = dirs._ystjmavfvf6v ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .source = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _7ft8dayafs70 = Package{
        .directory = dirs._7ft8dayafs70,
        .pkg = Pkg{ .name = "glfw", .source = .{ .path = dirs._7ft8dayafs70 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _rvid0clm032e = Package{
        .directory = dirs._rvid0clm032e,
        .pkg = Pkg{ .name = "nanovg", .source = .{ .path = dirs._rvid0clm032e ++ "/src/nanovg.zig" }, .dependencies = null },
    };
    pub const _x5su0m0e7yxg = Package{
        .directory = dirs._x5su0m0e7yxg,
        .pkg = Pkg{ .name = "zalgebra", .source = .{ .path = dirs._x5su0m0e7yxg ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _2i2jr6xhwjml = Package{
        .directory = dirs._2i2jr6xhwjml,
        .pkg = Pkg{ .name = "gl", .source = .{ .path = dirs._2i2jr6xhwjml ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _e1xxnyj4bani = Package{
        .directory = dirs._e1xxnyj4bani,
        .pkg = Pkg{ .name = "glfw", .source = .{ .path = dirs._e1xxnyj4bani ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _fmcf3oheu8gr = Package{
        .directory = dirs._fmcf3oheu8gr,
        .pkg = Pkg{ .name = "nanovg", .source = .{ .path = dirs._fmcf3oheu8gr ++ "/src/nanovg.zig" }, .dependencies = null },
    };
    pub const _4wijkno7k5j6 = Package{
        .directory = dirs._4wijkno7k5j6,
        .pkg = Pkg{ .name = "build-glfw", .source = .{ .path = dirs._4wijkno7k5j6 ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "c", },
    };
};

pub const packages = &[_]Package{
    package_data._ry8lll9fuc4y,
    package_data._ystjmavfvf6v,
    package_data._3hmo0glo2xj9,
    package_data._7ft8dayafs70,
    package_data._rvid0clm032e,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._ry8lll9fuc4y;
    pub const gl = package_data._ystjmavfvf6v;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const glfw = package_data._7ft8dayafs70;
    pub const nanovg = package_data._rvid0clm032e;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_3v3.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const nanovg = @import(".zigmod/deps/git/github.com/fabioarnold/nanovg-zig/src/nanovg.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
