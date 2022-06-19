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
    pub const _imhc2jy4th6h = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _22ha0v6edyf8 = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _nq5kqrdgoelu = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _jynrc18x3w3c = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _qmc9z5ahd2i9 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _9q4c3h6qgkqs = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _1zk4fwc4ofuk = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _ahxe74eecw4c = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _x9dup6xjdsn0 = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _imhc2jy4th6h = Package{
        .directory = dirs._imhc2jy4th6h,
        .pkg = Pkg{ .name = "zalgebra", .source = .{ .path = dirs._imhc2jy4th6h ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _22ha0v6edyf8 = Package{
        .directory = dirs._22ha0v6edyf8,
        .pkg = Pkg{ .name = "gl", .source = .{ .path = dirs._22ha0v6edyf8 ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .source = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _nq5kqrdgoelu = Package{
        .directory = dirs._nq5kqrdgoelu,
        .pkg = Pkg{ .name = "zig-tracy", .source = .{ .path = dirs._nq5kqrdgoelu ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _jynrc18x3w3c = Package{
        .directory = dirs._jynrc18x3w3c,
        .pkg = Pkg{ .name = "glfw", .source = .{ .path = dirs._jynrc18x3w3c ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _qmc9z5ahd2i9 = Package{
        .directory = dirs._qmc9z5ahd2i9,
        .pkg = Pkg{ .name = "zalgebra", .source = .{ .path = dirs._qmc9z5ahd2i9 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _9q4c3h6qgkqs = Package{
        .directory = dirs._9q4c3h6qgkqs,
        .pkg = Pkg{ .name = "gl", .source = .{ .path = dirs._9q4c3h6qgkqs ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _1zk4fwc4ofuk = Package{
        .directory = dirs._1zk4fwc4ofuk,
        .pkg = Pkg{ .name = "zig-tracy", .source = .{ .path = dirs._1zk4fwc4ofuk ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _ahxe74eecw4c = Package{
        .directory = dirs._ahxe74eecw4c,
        .pkg = Pkg{ .name = "glfw", .source = .{ .path = dirs._ahxe74eecw4c ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _x9dup6xjdsn0 = Package{
        .directory = dirs._x9dup6xjdsn0,
        .pkg = Pkg{ .name = "build-glfw", .source = .{ .path = dirs._x9dup6xjdsn0 ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "c", },
    };
};

pub const packages = &[_]Package{
    package_data._imhc2jy4th6h,
    package_data._22ha0v6edyf8,
    package_data._3hmo0glo2xj9,
    package_data._nq5kqrdgoelu,
    package_data._jynrc18x3w3c,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._imhc2jy4th6h;
    pub const gl = package_data._22ha0v6edyf8;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._nq5kqrdgoelu;
    pub const glfw = package_data._jynrc18x3w3c;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_3v3.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
