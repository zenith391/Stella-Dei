const std = @import("std");
pub const gl = @import("gl");
const glfw = @import("glfw");
const za = @import("zalgebra");
const tracy = @import("vendor/tracy.zig");

const Renderer = @import("renderer.zig").Renderer;
const Texture = @import("renderer.zig").Texture;
const AudioSubsystem = @import("audio.zig").AudioSubsystem;
const EventLoop = @import("loop.zig").EventLoop;
const Job = @import("loop.zig").Job;

var renderer: Renderer = undefined;

const SplashScreenState = @import("states/splash_screen.zig").SplashScreenState;
const MainMenuState = @import("states/main_menu.zig").MainMenuState;
const GameIntroState = @import("states/game_intro.zig").GameIntroState;
const PlayState = @import("states/play.zig").PlayState;

pub const log_level = .debug;

pub const GameState = union(enum) {
    SplashScreen: SplashScreenState,
    MainMenu: MainMenuState,
    GameIntro: GameIntroState,
    Playing: PlayState,
};

pub const Game = struct {
    state: GameState,
    /// False if the state doesn't contain a valid value
    state_init: bool = false,
    audio: AudioSubsystem,
    window: glfw.Window,
    renderer: *Renderer,
    loop: *EventLoop,
    allocator: std.mem.Allocator,
    imgui_state: std.StringHashMap(@import("ui.zig").UiComponentState),
    fps: f32 = 60,
    /// Job that will be deinit at the end. In the code this is only used for a
    /// job's that's created to call Game.setState from a state, but then can't
    /// be deinit immediately because otherwise you'd have a biting-its-tail problem
    ///   setState -> calls deinit -> deinits setState's (and deinit's) stack
    ///      = /!\ PROBLEM
    /// So the job in this field will only be called during Game.deinit
    /// Note: it could be called sooner, as it only needs to be called anytime
    /// after setState.
    deinitJob: ?*Job(void) = null,
    oldMouseX: f32 = 0,
    oldMouseY: f32 = 0,

    pub fn init(allocator: std.mem.Allocator, window: glfw.Window, ptrRenderer: *Renderer, ptrLoop: *EventLoop) !Game {
        return Game{
            .state = .{ .MainMenu = undefined },
            .audio = try AudioSubsystem.init(allocator),
            .window = window,
            .renderer = ptrRenderer,
            .loop = ptrLoop,
            .allocator = allocator,
            .imgui_state = std.StringHashMap(@import("ui.zig").UiComponentState).init(allocator),
        };
    }

    pub fn setState(self: *Game, comptime NewState: type) void {
        std.log.info("Loading {s}...", .{@typeName(NewState)});
        defer std.log.info("Loaded", .{});

        const new_state = NewState.init(self);
        if (self.state_init) self.deinitState();
        self.imgui_state.clearRetainingCapacity();

        inline for (std.meta.fields(GameState)) |field| {
            if (field.type == NewState) {
                self.state = @unionInit(GameState, field.name, new_state);
                self.state_init = true;
                return;
            }
        }
        @compileError(@typeName(NewState) ++ " is not in the GameState union");
    }

    pub fn getTime() f64 {
        return @as(f64, @floatFromInt(std.time.milliTimestamp()));
    }

    pub fn deinitState(self: *Game) void {
        inline for (std.meta.fields(GameState)) |field| {
            // if the field is active
            if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
                if (@hasDecl(field.type, "deinit")) {
                    @field(self.state, field.name).deinit(self);
                    return;
                }
            }
        }
    }

    pub fn deinit(self: *Game) void {
        if (self.deinitJob) |job| {
            job.deinit();
        }
        self.deinitState();
        self.audio.deinit();
        self.imgui_state.deinit();
    }
};

var game: Game = undefined;

fn mousePressed(window: glfw.Window, button: glfw.mouse_button.MouseButton) void {
    _ = window;
    inline for (std.meta.fields(GameState)) |field| {
        // if it is the current game state
        if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
            // and it has mousePressed()
            if (comptime @hasDecl(field.type, "mousePressed")) {
                // call it
                @field(game.state, field.name).mousePressed(&game, button);
                return;
            }
        }
    }
}

fn mouseScroll(window: glfw.Window, xOffset: f64, yOffset: f64) void {
    _ = window;
    _ = xOffset;
    inline for (std.meta.fields(GameState)) |field| {
        // if it is the current game state
        if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
            // and it has mouseScroll()
            if (comptime @hasDecl(field.type, "mouseScroll")) {
                // call it
                @field(game.state, field.name).mouseScroll(&game, yOffset);
                return;
            }
        }
    }
}

fn cursorPosCallback(window: glfw.Window, xpos: f64, ypos: f64) void {
    _ = window;
    inline for (std.meta.fields(GameState)) |field| {
        // if it is the current game state
        if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
            // and it has mouseMoved()
            if (comptime @hasDecl(field.type, "mouseMoved")) {
                // call it
                @field(game.state, field.name).mouseMoved(
                    &game,
                    @as(f32, @floatCast(xpos)),
                    @as(f32, @floatCast(ypos)),
                    @as(f32, @floatCast(xpos)) - game.oldMouseX,
                    @as(f32, @floatCast(ypos)) - game.oldMouseY,
                );
                game.oldMouseX = @as(f32, @floatCast(xpos));
                game.oldMouseY = @as(f32, @floatCast(ypos));
                return;
            }
        }
    }
}

fn keyCallback(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
    if (key == .F11 and action == .press) {
        if (window.getMonitor() == null) {
            const monitor = glfw.Monitor.getPrimary().?;
            const videoMode = monitor.getVideoMode().?;
            window.setMonitor(monitor, 0, 0, videoMode.getWidth(), videoMode.getHeight(), null);
        } else {
            window.setMonitor(null, 100, 100, 1280, 720, null);
        }
    }

    inline for (std.meta.fields(GameState)) |field| {
        // if it is the current game state
        if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
            // and it has mouseMoved()
            if (comptime @hasDecl(field.type, "keyCallback")) {
                // call it
                @field(game.state, field.name).keyCallback(&game, key, scancode, action, mods);
                return;
            }
        }
    }
}

fn render(window: glfw.Window) void {
    game.audio.update();

    const size = window.getFramebufferSize();
    gl.viewport(0, 0, @as(c_int, @intCast(size.width)), @as(c_int, @intCast(size.height)));
    gl.clearColor(0, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT);
    renderer.framebufferSize = za.Vec2.new(@as(f32, @floatFromInt(size.width)), @as(f32, @floatFromInt(size.height)));

    const zone = tracy.ZoneN(@src(), "Render");
    defer zone.End();
    // Call the render() function of the current game state
    inline for (std.meta.fields(GameState)) |field| {
        if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
            @field(game.state, field.name).render(&game, &renderer);
        }
    }

    renderer.startUI();
    // Call the renderUI() function of the current game state, if it has one.
    inline for (std.meta.fields(GameState)) |field| {
        if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
            if (comptime @hasDecl(field.type, "renderUI")) {
                @field(game.state, field.name).renderUI(&game, &renderer);
                break;
            }
        }
    }
    renderer.endUI();
}

fn updateLoop(loop: *EventLoop, window: glfw.Window) void {
    _ = loop;
    var fullLoopTime: f32 = 0;
    var dt: f32 = 0.016;
    while (!window.shouldClose()) {
        // Call the update() function of the current game state, if it has one.

        var timer = std.time.Timer.start() catch unreachable; // this just assumes a clock is available
        inline for (std.meta.fields(GameState)) |field| {
            if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
                if (comptime @hasDecl(field.type, "update")) {
                    dt = dt * 0.9 + fullLoopTime * 0.1; // smoothly go to fullLoopTime
                    @field(game.state, field.name).update(&game, dt);
                    break;
                }
            }
        }
        const elapsed = timer.read();
        std.time.sleep((16666666 * 2) -| elapsed);
        fullLoopTime = @as(f32, @floatFromInt(timer.read())) / @as(f32, @floatFromInt(std.time.ns_per_s));
    }
}

const perlin = @import("perlin.zig").p2d;

/// This is used by zig-opengl library to load OpenGL functions from GLFW
fn getProcAddress(_: void, name: [:0]const u8) ?*anyopaque {
    const proc = glfw.getProcAddress(name);
    return @as(?*anyopaque, @ptrFromInt(@intFromPtr(proc)));
}

fn mouseButtonCallback(window: glfw.Window, button: glfw.mouse_button.MouseButton, action: glfw.Action, _: glfw.Mods) void {
    if (action == .press) {
        mousePressed(window, button);
    }
}

/// Shows an error message box on Windows, logs on console on other platforms.
/// In all cases it exists with return code 1.
fn fatalCrash(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) noreturn {
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    if (@import("builtin").target.os.tag == .windows) {
        const msgUtf8 = std.fmt.allocPrint(allocator, fmt, args) catch std.process.exit(1);
        defer allocator.free(msgUtf8);

        const msgUtf16 = std.unicode.utf8ToUtf16LeWithNull(allocator, msgUtf8) catch std.process.exit(1);
        defer allocator.free(msgUtf16);

        _ = std.os.windows.user32.messageBoxW(null, msgUtf16, L("Fatal Error"), std.os.windows.user32.MB_ICONERROR | std.os.windows.user32.MB_OK) catch std.process.exit(1);
    } else {
        std.log.err(fmt, args);
    }
    std.process.exit(1);
}

pub fn main() !void {
    std.valgrind.callgrind.stopInstrumentation();
    // Only manually catch errors (and show them as message boxes) on Windows
    if (@import("builtin").target.os.tag == .windows) {
        main_wrap() catch |err| {
            var buffer: [16 * 1024]u8 = undefined;
            var stream = std.io.fixedBufferStream(&buffer);
            try stream.writer().print("Dang, we crashed! And it says {s} !\n", .{@errorName(err)});
            if (@errorReturnTrace()) |trace| {
                try stream.writer().print("\r\n  You even got a stack trace!\r\n\r\n", .{});
                try std.debug.writeStackTrace(trace.*, stream.writer(), std.heap.page_allocator, try std.debug.getSelfDebugInfo(), std.debug.TTY.Config.no_color);
            }
            fatalCrash(std.heap.page_allocator, "{s}", .{stream.getWritten()});
        };
    } else {
        // Let Zig handle it (it'll log in the terminal, along with optional debug info)
        try main_wrap();
    }
}

fn main_wrap() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    //     // If Tracy is enabled, pass-through all allocations to it
    // var tracyAlloc = @import("tracy_allocator.zig").TracyAllocator.init(gpa.allocator());
    // const allocator = if (tracy.enabled) tracyAlloc.allocator() else gpa.allocator();
    // _ = allocator;
    const allocator = gpa.allocator();
    // tracy.InitThread();

    if (glfw.init(.{}) == false) {
        fatalCrash(std.heap.page_allocator, "could not initialize glfw", .{});
    }
    defer glfw.terminate();

    var window = glfw.Window.create(1280, 720, "Stella Dei", null, null, .{
        .opengl_profile = .opengl_core_profile,
        .context_version_major = 4,
        .context_version_minor = 0,
    }) orelse blk: {
        glfw.getErrorCode() catch |err| {
            switch (err) {
                error.APIUnavailable => fatalCrash(allocator, "OpenGL is not available! Install drivers!", .{}),
                error.VersionUnavailable => {
                    std.log.warn("Switching to OpenGL 3.3 as support for OpenGL 4.0+ is missing", .{});
                    break :blk glfw.Window.create(1280, 720, "Stella Dei", null, null, .{
                        .opengl_profile = .opengl_core_profile,
                        .context_version_major = 3,
                        .context_version_minor = 3,
                    }) orelse {
                        fatalCrash(allocator, "OpenGL 3.3 (core profile) is not available! Upgrade your drivers!", .{});
                    };
                },
                else => fatalCrash(allocator, "Could not create the game window: {s}", .{@errorName(err)}),
            }
        };
        unreachable;
    };
    defer window.destroy();
    window.setCursorPosCallback(cursorPosCallback);
    window.setMouseButtonCallback(mouseButtonCallback);
    window.setScrollCallback(mouseScroll);
    window.setKeyCallback(keyCallback);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);
    std.log.debug("Load OpenGL functions", .{});
    try gl.load({}, getProcAddress);

    std.log.debug("Initializing renderer..", .{});
    renderer = try Renderer.init(allocator, window);
    defer renderer.deinit();

    std.log.debug("Initializing event loop..", .{});
    var loop = EventLoop.init();

    loop.beginEvent(); // begin main() event to avoid the loop stopping too soon
    defer loop.endEvent();
    try loop.start(allocator);
    game = try Game.init(allocator, window, &renderer, &loop);

    // Start with opening sequence
    // To see the code, look in src/states/splash_screen.zig
    if (@import("builtin").mode == .Debug) {
        // Skip the opening sequence if we're in debug mode
        // To see the code, look in src/states/main_menu.zig
        nosuspend game.setState(MainMenuState);
    } else {
        nosuspend game.setState(SplashScreenState);
    }
    defer game.deinit();

    std.log.debug("Creating update loop job..", .{});
    var updateLoopJob = try Job(void).create(&loop);
    defer {
        // 'await' without making the function async
        while (!updateLoopJob.isCompleted()) {
            std.atomic.spinLoopHint();
        }
        updateLoopJob.deinit();
    }
    try updateLoopJob.call(updateLoop, .{ &loop, window });

    std.log.debug("Done!", .{});

    var fpsTimer = try std.time.Timer.start();
    while (!window.shouldClose()) {
        glfw.makeContextCurrent(window);
        render(window);

        window.swapBuffers();
        glfw.pollEvents();
        tracy.FrameMark();

        const frameTime = fpsTimer.lap();
        const fps = 1.0 / (@as(f32, @floatFromInt(frameTime)) / std.time.ns_per_s);
        game.fps = fps;
        // std.log.debug("{d} fps", .{fps});
    }
}

const expect = std.testing.expect;

test "main menu state" {
    var testGame = Game.init();
    try expect(std.meta.activeTag(testGame.state) == .MainMenu);

    testGame.setState(PlayState);
    try expect(std.meta.activeTag(testGame.state) == .Playing);
}
