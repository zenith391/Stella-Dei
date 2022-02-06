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
        inline for (pkg.system_libs) |item| {
            exe.linkSystemLibrary(item);
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
    vcpkg: bool = false,
};

fn checkMinZig(current: std.SemanticVersion, exe: *std.build.LibExeObjStep) void {
    const min = std.SemanticVersion.parse("null") catch return;
    if (current.order(min).compare(.lt)) @panic(exe.builder.fmt("Your Zig version v{} does not meet the minimum build requirement of v{}", .{current, min}));
}

pub const dirs = struct {
    pub const _root = "";
    pub const _93jjp4rc0htn = cache ++ "/../..";
    pub const _iy6rc8sx1ah8 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _o8bylvhqzwlo = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _flen6xue5f4h = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _ycoqcy4wm57u = cache ++ "/git/github.com/MasterQ32/zig-opengl";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _iy6rc8sx1ah8 = Package{
        .directory = dirs._iy6rc8sx1ah8,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._iy6rc8sx1ah8 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _o8bylvhqzwlo = Package{
        .directory = dirs._o8bylvhqzwlo,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._o8bylvhqzwlo ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _flen6xue5f4h = Package{
        .directory = dirs._flen6xue5f4h,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._flen6xue5f4h ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _ycoqcy4wm57u = Package{
        .directory = dirs._ycoqcy4wm57u,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._ycoqcy4wm57u ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "glfw", "c", "glfw" },
    };
};

pub const packages = &[_]Package{
    package_data._iy6rc8sx1ah8,
    package_data._o8bylvhqzwlo,
    package_data._3hmo0glo2xj9,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._iy6rc8sx1ah8;
    pub const gl = package_data._o8bylvhqzwlo;
    pub const zigimg = package_data._3hmo0glo2xj9;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_4v6.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
};
