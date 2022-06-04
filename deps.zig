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
    pub const _zq5iqpwavdh2 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _66n7pgg1c4kt = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _35smsidt3jk9 = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _waki4udw4sw5 = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _wz553969wvug = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _1ykdpru6od5p = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _xwdwyhi9u0nj = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _4o4ympedr02g = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _nwe38l4okh63 = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _zq5iqpwavdh2 = Package{
        .directory = dirs._zq5iqpwavdh2,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._zq5iqpwavdh2 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _66n7pgg1c4kt = Package{
        .directory = dirs._66n7pgg1c4kt,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._66n7pgg1c4kt ++ "/exports/gl_4v2.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _35smsidt3jk9 = Package{
        .directory = dirs._35smsidt3jk9,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._35smsidt3jk9 ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _waki4udw4sw5 = Package{
        .directory = dirs._waki4udw4sw5,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._waki4udw4sw5 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _wz553969wvug = Package{
        .directory = dirs._wz553969wvug,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._wz553969wvug ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _1ykdpru6od5p = Package{
        .directory = dirs._1ykdpru6od5p,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._1ykdpru6od5p ++ "/exports/gl_4v2.zig" }, .dependencies = null },
    };
    pub const _xwdwyhi9u0nj = Package{
        .directory = dirs._xwdwyhi9u0nj,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._xwdwyhi9u0nj ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _4o4ympedr02g = Package{
        .directory = dirs._4o4ympedr02g,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._4o4ympedr02g ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _nwe38l4okh63 = Package{
        .directory = dirs._nwe38l4okh63,
        .pkg = Pkg{ .name = "build-glfw", .path = .{ .path = dirs._nwe38l4okh63 ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "OpenCL", "c", "OpenCL", },
    };
};

pub const packages = &[_]Package{
    package_data._zq5iqpwavdh2,
    package_data._66n7pgg1c4kt,
    package_data._3hmo0glo2xj9,
    package_data._35smsidt3jk9,
    package_data._waki4udw4sw5,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._zq5iqpwavdh2;
    pub const gl = package_data._66n7pgg1c4kt;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._35smsidt3jk9;
    pub const glfw = package_data._waki4udw4sw5;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_4v2.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
