const std = @import("std");

const nvg = @import("nanovg");

const wasm = @import("web/wasm.zig");
const gl = @import("web/webgl.zig");
const keys = @import("web/keys.zig");
const console = @import("web/console.zig");

const Demo = @import("demo.zig");
const PerfGraph = @import("perf.zig");

var video_width: f32 = 1280;
var video_height: f32 = 720;
var video_scale: f32 = 1;

var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var allocator: std.mem.Allocator = undefined;
var vg: nvg = undefined;
var demo: Demo = undefined;
var fps: PerfGraph = undefined;

var prevt: f32 = 0;
var mx: f32 = 0;
var my: f32 = 0;
var blowup: bool = false;
var screenshot: bool = false;
var premult: bool = false;

export fn onInit() void {
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    allocator = gpa.allocator();
    wasm.global_allocator = allocator;

    vg = nvg.gl.init(allocator, .{}) catch {
        console.log("Failed to create NanoVG", .{});
        return;
    };

    demo.load(vg);
    fps = PerfGraph.init(.fps, "Frame Time");

    prevt = wasm.performanceNow() / 1000.0;
}

export fn onResize(w: c_uint, h: c_uint, s: f32) void {
    video_width = @as(f32, @floatFromInt(w));
    video_height = @as(f32, @floatFromInt(h));
    video_scale = s;
    gl.glViewport(0, 0, @as(i32, @intFromFloat(s * video_width)), @as(i32, @intFromFloat(s * video_height)));
}

export fn onKeyDown(key: c_uint) void {
    if (key == keys.KEY_SPACE) blowup = !blowup;
    if (key == keys.KEY_S) screenshot = true;
    if (key == keys.KEY_P) premult = !premult;
}

export fn onMouseMove(x: i32, y: i32) void {
    mx = @as(f32, @floatFromInt(x));
    my = @as(f32, @floatFromInt(y));
}

export fn onAnimationFrame() void {
    const t = wasm.performanceNow() / 1000.0;
    const dt = t - prevt;
    prevt = t;
    fps.update(dt);

    if (premult) {
        gl.glClearColor(0, 0, 0, 0);
    } else {
        gl.glClearColor(0.3, 0.3, 0.32, 1.0);
    }
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    vg.beginFrame(video_width, video_height, video_scale);

    demo.draw(vg, mx, my, video_width, video_height, t, blowup);
    fps.draw(vg, 5, 5);

    vg.endFrame();

    if (screenshot) {
        screenshot = false;
        const w = @as(i32, @intFromFloat(video_width * video_scale));
        const h = @as(i32, @intFromFloat(video_height * video_scale));
        const data = Demo.saveScreenshot(allocator, w, h, premult) catch return;
        defer allocator.free(data);
        const filename = "dump.png";
        const mimetype = "image/png";
        wasm.download(filename, filename.len, mimetype, mimetype.len, data.ptr, data.len);
    }
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = "[" ++ @tagName(level) ++ "] " ++ "(" ++ @tagName(scope) ++ "): ";
    console.log(prefix ++ format ++ "\n", args);
}
