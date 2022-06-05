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
    pub const _dt6c4u7mstk8 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _zu72frtmprum = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _zjp022pv8b91 = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _k0zk0kmuhmai = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _hzh1dea8igy5 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _whjeoc88ij2x = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _12vosbtzv5mw = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _9kra1lr71of5 = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _euk37gegtipw = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _dt6c4u7mstk8 = Package{
        .directory = dirs._dt6c4u7mstk8,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._dt6c4u7mstk8 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _zu72frtmprum = Package{
        .directory = dirs._zu72frtmprum,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._zu72frtmprum ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _zjp022pv8b91 = Package{
        .directory = dirs._zjp022pv8b91,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._zjp022pv8b91 ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _k0zk0kmuhmai = Package{
        .directory = dirs._k0zk0kmuhmai,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._k0zk0kmuhmai ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _hzh1dea8igy5 = Package{
        .directory = dirs._hzh1dea8igy5,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._hzh1dea8igy5 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _whjeoc88ij2x = Package{
        .directory = dirs._whjeoc88ij2x,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._whjeoc88ij2x ++ "/exports/gl_3v3.zig" }, .dependencies = null },
    };
    pub const _12vosbtzv5mw = Package{
        .directory = dirs._12vosbtzv5mw,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._12vosbtzv5mw ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _9kra1lr71of5 = Package{
        .directory = dirs._9kra1lr71of5,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._9kra1lr71of5 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _euk37gegtipw = Package{
        .directory = dirs._euk37gegtipw,
        .pkg = Pkg{ .name = "build-glfw", .path = .{ .path = dirs._euk37gegtipw ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "OpenCL", "c", "OpenCL", },
    };
};

pub const packages = &[_]Package{
    package_data._dt6c4u7mstk8,
    package_data._zu72frtmprum,
    package_data._3hmo0glo2xj9,
    package_data._zjp022pv8b91,
    package_data._k0zk0kmuhmai,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._dt6c4u7mstk8;
    pub const gl = package_data._zu72frtmprum;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._zjp022pv8b91;
    pub const glfw = package_data._k0zk0kmuhmai;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_3v3.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
