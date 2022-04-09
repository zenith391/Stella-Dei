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
    const min = std.SemanticVersion.parse("null") catch return;
    if (current.order(min).compare(.lt)) @panic(exe.builder.fmt("Your Zig version v{} does not meet the minimum build requirement of v{}", .{current, min}));
}

pub const dirs = struct {
    pub const _root = "";
    pub const _93jjp4rc0htn = cache ++ "/../..";
    pub const _8qahcfud6o1h = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _apgagn71hrhd = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _hec1d7upejba = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _yz5z9mm667rd = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _iym8wluloaj3 = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3ny92e6i02ob = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _8qahcfud6o1h = Package{
        .directory = dirs._8qahcfud6o1h,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._8qahcfud6o1h ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _apgagn71hrhd = Package{
        .directory = dirs._apgagn71hrhd,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._apgagn71hrhd ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _hec1d7upejba = Package{
        .directory = dirs._hec1d7upejba,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._hec1d7upejba ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _yz5z9mm667rd = Package{
        .directory = dirs._yz5z9mm667rd,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._yz5z9mm667rd ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _iym8wluloaj3 = Package{
        .directory = dirs._iym8wluloaj3,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._iym8wluloaj3 ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _3ny92e6i02ob = Package{
        .directory = dirs._3ny92e6i02ob,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._3ny92e6i02ob ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "glfw", "c", "glfw" },
    };
};

pub const packages = &[_]Package{
    package_data._8qahcfud6o1h,
    package_data._apgagn71hrhd,
    package_data._3hmo0glo2xj9,
    package_data._hec1d7upejba,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._8qahcfud6o1h;
    pub const gl = package_data._apgagn71hrhd;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._hec1d7upejba;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_4v6.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
};
