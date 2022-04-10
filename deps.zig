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
    pub const _s12k9t7pjey4 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _g7r8l77y21a4 = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _v9i8u24r7i6d = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _8emrqiccd9py = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _yvkr0y12lhil = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _gzh6uy09c3tt = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _kc3vmt2ny4vr = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _0tnwoap55ogn = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _jio0pr1ochhf = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _s12k9t7pjey4 = Package{
        .directory = dirs._s12k9t7pjey4,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._s12k9t7pjey4 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _g7r8l77y21a4 = Package{
        .directory = dirs._g7r8l77y21a4,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._g7r8l77y21a4 ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _v9i8u24r7i6d = Package{
        .directory = dirs._v9i8u24r7i6d,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._v9i8u24r7i6d ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _8emrqiccd9py = Package{
        .directory = dirs._8emrqiccd9py,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._8emrqiccd9py ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _yvkr0y12lhil = Package{
        .directory = dirs._yvkr0y12lhil,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._yvkr0y12lhil ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _gzh6uy09c3tt = Package{
        .directory = dirs._gzh6uy09c3tt,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._gzh6uy09c3tt ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _kc3vmt2ny4vr = Package{
        .directory = dirs._kc3vmt2ny4vr,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._kc3vmt2ny4vr ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _0tnwoap55ogn = Package{
        .directory = dirs._0tnwoap55ogn,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._0tnwoap55ogn ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _jio0pr1ochhf = Package{
        .directory = dirs._jio0pr1ochhf,
        .pkg = Pkg{ .name = "build-glfw", .path = .{ .path = dirs._jio0pr1ochhf ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "c", },
    };
};

pub const packages = &[_]Package{
    package_data._s12k9t7pjey4,
    package_data._g7r8l77y21a4,
    package_data._3hmo0glo2xj9,
    package_data._v9i8u24r7i6d,
    package_data._8emrqiccd9py,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._s12k9t7pjey4;
    pub const gl = package_data._g7r8l77y21a4;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._v9i8u24r7i6d;
    pub const glfw = package_data._8emrqiccd9py;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_4v6.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
