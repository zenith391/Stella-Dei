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
    pub const _z7gjvhvcpc8r = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _0t3r4gwiygkg = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _ft6slbpli41p = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _ny45cdc5gid0 = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _gepwnqx58yff = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _43o07js2wnca = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _r0l4c0stjr7r = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _8eqxecb7f5gh = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _z8s7fto1kw6y = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _z7gjvhvcpc8r = Package{
        .directory = dirs._z7gjvhvcpc8r,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._z7gjvhvcpc8r ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _0t3r4gwiygkg = Package{
        .directory = dirs._0t3r4gwiygkg,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._0t3r4gwiygkg ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _ft6slbpli41p = Package{
        .directory = dirs._ft6slbpli41p,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._ft6slbpli41p ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _ny45cdc5gid0 = Package{
        .directory = dirs._ny45cdc5gid0,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._ny45cdc5gid0 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _gepwnqx58yff = Package{
        .directory = dirs._gepwnqx58yff,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._gepwnqx58yff ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _43o07js2wnca = Package{
        .directory = dirs._43o07js2wnca,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._43o07js2wnca ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _r0l4c0stjr7r = Package{
        .directory = dirs._r0l4c0stjr7r,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._r0l4c0stjr7r ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _8eqxecb7f5gh = Package{
        .directory = dirs._8eqxecb7f5gh,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._8eqxecb7f5gh ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _z8s7fto1kw6y = Package{
        .directory = dirs._z8s7fto1kw6y,
        .pkg = Pkg{ .name = "build-glfw", .path = .{ .path = dirs._z8s7fto1kw6y ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "c", },
    };
};

pub const packages = &[_]Package{
    package_data._z7gjvhvcpc8r,
    package_data._0t3r4gwiygkg,
    package_data._3hmo0glo2xj9,
    package_data._ft6slbpli41p,
    package_data._ny45cdc5gid0,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._z7gjvhvcpc8r;
    pub const gl = package_data._0t3r4gwiygkg;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._ft6slbpli41p;
    pub const glfw = package_data._ny45cdc5gid0;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_3v3.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
