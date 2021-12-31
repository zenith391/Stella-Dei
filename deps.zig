const std = @import("std");
const builtin = @import("builtin");
const Pkg = std.build.Pkg;
const string = []const u8;

pub const cache = ".zigmod/deps";

pub fn addAllTo(exe: *std.build.LibExeObjStep) void {
    @setEvalBranchQuota(1_000_000);
    for (packages) |pkg| {
        exe.addPackage(pkg.pkg.?);
    }
    var llc = false;
    var vcpkg = false;
    inline for (std.meta.declarations(package_data)) |decl| {
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

const dirs = struct {
    pub const _root = "";
    pub const _93jjp4rc0htn = cache ++ "/../..";
    pub const _qj02k9cy7vs9 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _grvnpl39iyop = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _03b2dkm2awve = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _ktusrxvydg6m = cache ++ "/git/github.com/MasterQ32/zig-opengl";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _qj02k9cy7vs9 = Package{
        .directory = dirs._qj02k9cy7vs9,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._qj02k9cy7vs9 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _grvnpl39iyop = Package{
        .directory = dirs._grvnpl39iyop,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._grvnpl39iyop ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _03b2dkm2awve = Package{
        .directory = dirs._03b2dkm2awve,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._03b2dkm2awve ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _ktusrxvydg6m = Package{
        .directory = dirs._ktusrxvydg6m,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._ktusrxvydg6m ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "glfw", "c", "glfw" },
    };
};

pub const packages = &[_]Package{
    package_data._qj02k9cy7vs9,
    package_data._grvnpl39iyop,
    package_data._3hmo0glo2xj9,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._qj02k9cy7vs9;
    pub const gl = package_data._grvnpl39iyop;
    pub const zigimg = package_data._3hmo0glo2xj9;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_4v6.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
};
