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
    pub const _sv24brlrym6p = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _oml7uf6ev5kx = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _vj9g7ckkkr1v = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _k303n8hx9nh5 = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _eq13t658qlhp = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _8dj25hvvq6x2 = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _2j3q4mctsg0m = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _tidgnqzstbo0 = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _yxp31ala0ogn = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _sv24brlrym6p = Package{
        .directory = dirs._sv24brlrym6p,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._sv24brlrym6p ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _oml7uf6ev5kx = Package{
        .directory = dirs._oml7uf6ev5kx,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._oml7uf6ev5kx ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _vj9g7ckkkr1v = Package{
        .directory = dirs._vj9g7ckkkr1v,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._vj9g7ckkkr1v ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _k303n8hx9nh5 = Package{
        .directory = dirs._k303n8hx9nh5,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._k303n8hx9nh5 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _eq13t658qlhp = Package{
        .directory = dirs._eq13t658qlhp,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._eq13t658qlhp ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _8dj25hvvq6x2 = Package{
        .directory = dirs._8dj25hvvq6x2,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._8dj25hvvq6x2 ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _2j3q4mctsg0m = Package{
        .directory = dirs._2j3q4mctsg0m,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._2j3q4mctsg0m ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _tidgnqzstbo0 = Package{
        .directory = dirs._tidgnqzstbo0,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._tidgnqzstbo0 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _yxp31ala0ogn = Package{
        .directory = dirs._yxp31ala0ogn,
        .pkg = Pkg{ .name = "build-glfw", .path = .{ .path = dirs._yxp31ala0ogn ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "OpenCL", "c", "OpenCL", },
    };
};

pub const packages = &[_]Package{
    package_data._sv24brlrym6p,
    package_data._oml7uf6ev5kx,
    package_data._3hmo0glo2xj9,
    package_data._vj9g7ckkkr1v,
    package_data._k303n8hx9nh5,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._sv24brlrym6p;
    pub const gl = package_data._oml7uf6ev5kx;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._vj9g7ckkkr1v;
    pub const glfw = package_data._k303n8hx9nh5;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_3v3.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
