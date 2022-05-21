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
    pub const _wllanwj7w7d3 = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _1w26zzzskmq8 = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _3hmo0glo2xj9 = cache ++ "/git/github.com/zigimg/zigimg";
    pub const _52aocl1tx7jy = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _801pchu4tuu9 = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _4aotep54dmfg = cache ++ "/git/github.com/kooparse/zalgebra";
    pub const _sad4tjjieovg = cache ++ "/git/github.com/MasterQ32/zig-opengl";
    pub const _6684gldsi5c4 = cache ++ "/git/github.com/SpexGuy/Zig-Tracy";
    pub const _l28t1wf60xvu = cache ++ "/git/github.com/hexops/mach-glfw";
    pub const _mz449fdts1q4 = cache ++ "/git/github.com/hexops/mach-glfw";
};

pub const package_data = struct {
    pub const _93jjp4rc0htn = Package{
        .directory = dirs._93jjp4rc0htn,
    };
    pub const _wllanwj7w7d3 = Package{
        .directory = dirs._wllanwj7w7d3,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._wllanwj7w7d3 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _1w26zzzskmq8 = Package{
        .directory = dirs._1w26zzzskmq8,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._1w26zzzskmq8 ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _3hmo0glo2xj9 = Package{
        .directory = dirs._3hmo0glo2xj9,
        .pkg = Pkg{ .name = "zigimg", .path = .{ .path = dirs._3hmo0glo2xj9 ++ "/zigimg.zig" }, .dependencies = null },
    };
    pub const _52aocl1tx7jy = Package{
        .directory = dirs._52aocl1tx7jy,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._52aocl1tx7jy ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _801pchu4tuu9 = Package{
        .directory = dirs._801pchu4tuu9,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._801pchu4tuu9 ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _4aotep54dmfg = Package{
        .directory = dirs._4aotep54dmfg,
        .pkg = Pkg{ .name = "zalgebra", .path = .{ .path = dirs._4aotep54dmfg ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _sad4tjjieovg = Package{
        .directory = dirs._sad4tjjieovg,
        .pkg = Pkg{ .name = "gl", .path = .{ .path = dirs._sad4tjjieovg ++ "/exports/gl_4v6.zig" }, .dependencies = null },
    };
    pub const _6684gldsi5c4 = Package{
        .directory = dirs._6684gldsi5c4,
        .pkg = Pkg{ .name = "zig-tracy", .path = .{ .path = dirs._6684gldsi5c4 ++ "/tracy.zig" }, .dependencies = null },
    };
    pub const _l28t1wf60xvu = Package{
        .directory = dirs._l28t1wf60xvu,
        .pkg = Pkg{ .name = "glfw", .path = .{ .path = dirs._l28t1wf60xvu ++ "/src/main.zig" }, .dependencies = null },
    };
    pub const _mz449fdts1q4 = Package{
        .directory = dirs._mz449fdts1q4,
        .pkg = Pkg{ .name = "build-glfw", .path = .{ .path = dirs._mz449fdts1q4 ++ "/build.zig" }, .dependencies = null },
    };
    pub const _root = Package{
        .directory = dirs._root,
        .system_libs = &.{ "c", "OpenCL", "c", "OpenCL", },
    };
};

pub const packages = &[_]Package{
    package_data._wllanwj7w7d3,
    package_data._1w26zzzskmq8,
    package_data._3hmo0glo2xj9,
    package_data._52aocl1tx7jy,
    package_data._801pchu4tuu9,
};

pub const pkgs = struct {
    pub const zalgebra = package_data._wllanwj7w7d3;
    pub const gl = package_data._1w26zzzskmq8;
    pub const zigimg = package_data._3hmo0glo2xj9;
    pub const zig_tracy = package_data._52aocl1tx7jy;
    pub const glfw = package_data._801pchu4tuu9;
};

pub const imports = struct {
    pub const zalgebra = @import(".zigmod/deps/git/github.com/kooparse/zalgebra/src/main.zig");
    pub const gl = @import(".zigmod/deps/git/github.com/MasterQ32/zig-opengl/exports/gl_4v6.zig");
    pub const zigimg = @import(".zigmod/deps/git/github.com/zigimg/zigimg/zigimg.zig");
    pub const zig_tracy = @import(".zigmod/deps/git/github.com/SpexGuy/Zig-Tracy/tracy.zig");
    pub const glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/src/main.zig");
    pub const build_glfw = @import(".zigmod/deps/git/github.com/hexops/mach-glfw/build.zig");
};
