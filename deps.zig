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
    pub const _x1addhwcav5q = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _w5rir382noyw = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _yb3qkhq5qoup = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _crv5ygxfxhus = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _i0o763yqx633 = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _h7gkg5plfah1 = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _x1addhwcav5q = Package{
        .directory = dirs._x1addhwcav5q,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._x1addhwcav5q ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _w5rir382noyw = Package{
        .directory = dirs._w5rir382noyw,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._w5rir382noyw ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _yb3qkhq5qoup = Package{
        .directory = dirs._yb3qkhq5qoup,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._yb3qkhq5qoup ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _crv5ygxfxhus = Package{
        .directory = dirs._crv5ygxfxhus,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._crv5ygxfxhus ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _i0o763yqx633 = Package{
        .directory = dirs._i0o763yqx633,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._i0o763yqx633 ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _h7gkg5plfah1 = Package{
        .directory = dirs._h7gkg5plfah1,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._h7gkg5plfah1 ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "glfw", "c", "glfw" },
    };
};

pub const packages = &[_]Package{
    package_data._x1addhwcav5q,
    package_data._w5rir382noyw,
    package_data._3hmo0glo2xj9,
    package_data._yb3qkhq5qoup,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._x1addhwcav5q;
    pub const gl = package_data._w5rir382noyw;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._yb3qkhq5qoup;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_4v6.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
};
