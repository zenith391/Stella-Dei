const std = @import("std");
const Pkg = std.build.Pkg;
const string = []const u8;

pub const cache = ".zigmod/deps";

pub fn addAllTo(exe: *std.build.LibExeObjStep) void {
    @setEvalBranchQuota(1_000_000);
    for (packages) |pkg| {
        exe.addPackage(pkg.pkg.?);
    }
    inline for (std.meta.declarations(package_data)) |decl| {
        const pkg = @as(Package, @field(package_data, decl.name));
        var llc = false;
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
        if (llc) {
            exe.linkLibC();
        }
    }
}

pub const Package = struct {
    directory: string,
    pkg: ?Pkg = null,
    c_include_dirs: []const string = &.{},
    c_source_files: []const string = &.{},
    c_source_flags: []const string = &.{},
    system_libs: []const string = &.{},
};

const dirs = struct {
    pub const _root = "";
    pub const _93jjp4rc0htn = cache ++ "/../..";
    pub const _h9ju4bhu17mw = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _8jdzblhxyk31 = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _h9ju4bhu17mw = Package{
        .directory = dirs._h9ju4bhu17mw,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._h9ju4bhu17mw ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _8jdzblhxyk31 = Package{
        .directory = dirs._8jdzblhxyk31,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._8jdzblhxyk31 ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "glfw" },
    };
};

pub const packages = &[_]Package{
    package_data._h9ju4bhu17mw,
    package_data._8jdzblhxyk31,
    package_data._3hmo0glo2xj9,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._h9ju4bhu17mw;
    pub const gl = package_data._8jdzblhxyk31;
    pub const zigimg = package_data._3hmo0glo2xj9;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_4v6.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
};
