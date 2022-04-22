const std   = @import("std");
const gl    = @import("gl");
const glfw  = @import("glfw");
const za    = @import("zalgebra");
const tracy = @import("vendor/tracy.zig");

const Renderer = @import("renderer.zig").Renderer;
const Texture = @import("renderer.zig").Texture;
const AudioSubsystem = @import("audio.zig").AudioSubsystem;
const EventLoop = @import("loop.zig").EventLoop;
const Job = @import("loop.zig").Job;

var renderer: Renderer = undefined;
var texture: Texture = undefined;

const MainMenuState = @import("states/main_menu.zig").MainMenuState;
const PlayState     = @import("states/play.zig").PlayState;

pub const GameState = union(enum) {
	MainMenu: MainMenuState,
	Playing: PlayState,
};

pub const Game = struct {
	state: GameState,
	audio: AudioSubsystem,
	window: glfw.Window,
	renderer: *Renderer,
	loop: *EventLoop,
	allocator: std.mem.Allocator,
	/// Job that will be deinit at the end. In the code this is only used for a
	/// job's that's created to call Game.setState from a state, but then can't
	/// be deinit immediately because otherwise you'd have a biting-its-tail problem
	///   setState -> calls deinit -> deinits setState's (and deinit's) stack
	///      = /!\ PROBLEM
	/// So the job in this field will only be called during Game.deinit
	/// Note: it could be called sooner, as it only needs to be called anytime
	/// after setState.
	deinitJob: ?*Job(void) = null,

	pub fn init(allocator: std.mem.Allocator, window: glfw.Window, ptrRenderer: *Renderer, ptrLoop: *EventLoop) !Game {
		return Game {
			.state = .{ .MainMenu = .{} },
			.audio = try AudioSubsystem.init(allocator),
			.window = window,
			.renderer = ptrRenderer,
			.loop = ptrLoop,
			.allocator = allocator,
		};
	}

	pub fn setState(self: *Game, comptime NewState: type) void {
		var state = NewState.init(self);
		self.deinitState();

		inline for (std.meta.fields(GameState)) |field| {
			if (field.field_type == NewState) {
				self.state = @unionInit(GameState, field.name, state);
				return;
			}
		}
		@compileError(@typeName(NewState) ++ " is not in the GameState union");
	}

	pub fn deinitState(self: *Game) void {
		inline for (std.meta.fields(GameState)) |field| {
			// if the field is active
			if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
				if (@hasDecl(field.field_type, "deinit")) {
					@field(self.state, field.name).deinit();
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
	}
};

var game: Game = undefined;

fn mousePressed(window: glfw.Window, button: glfw.mouse_button.MouseButton) void {
	_ = window;
	inline for (std.meta.fields(GameState)) |field| {
		// if it is the current game state
		if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
			// and it has mousePressed()
			if (comptime @hasDecl(field.field_type, "mousePressed")) {
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
	game.renderer.onScroll(@floatCast(f32, xOffset), @floatCast(f32, yOffset));
	inline for (std.meta.fields(GameState)) |field| {
		// if it is the current game state
		if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
			// and it has mouseScroll()
			if (comptime @hasDecl(field.field_type, "mouseScroll")) {
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
			if (comptime @hasDecl(field.field_type, "mouseMoved")) {
				// call it
				@field(game.state, field.name).mouseMoved(&game, @floatCast(f32, xpos), @floatCast(f32, ypos));
				return;
			}
		}
	}
}

fn render(window: glfw.Window) void {
	game.audio.update();

	const size = window.getFramebufferSize() catch unreachable;
	gl.viewport(0, 0, @intCast(c_int, size.width), @intCast(c_int, size.height));
	gl.clearColor(0, 0, 0, 1);
	gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT);
	renderer.framebufferSize = za.Vec2.new(@intToFloat(f32, size.width), @intToFloat(f32, size.height));

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
			if (comptime @hasDecl(field.field_type, "renderUI")) {
				@field(game.state, field.name).renderUI(&game, &renderer);
				break;
			}
		}
	}
	renderer.endUI();
}

fn updateLoop(loop: *EventLoop, window: glfw.Window) void {
	loop.yield();
	while (!window.shouldClose()) {
		// Call the update() function of the current game state, if it has one.
		inline for (std.meta.fields(GameState)) |field| {
			if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
				if (comptime @hasDecl(field.field_type, "update")) {
					var timer = std.time.Timer.start() catch unreachable; // this just assumes a clock is available
					@field(game.state, field.name).update(&game);
					const elapsed = timer.read();
					std.time.sleep(16 * std.time.ns_per_ms -| elapsed);
					break;
				}
			}
		}
		loop.yield();
	}
}

const perlin = @import("perlin.zig").p2d;

/// This is used by zig-opengl library to load OpenGL functions from GLFW
fn getProcAddress(_: void, name: [:0]const u8) ?*anyopaque {
	var proc = glfw.getProcAddress(name);
	return @intToPtr(?*anyopaque, @ptrToInt(proc));
}

fn mouseButtonCallback(window: glfw.Window, button: glfw.mouse_button.MouseButton, action: glfw.Action, _: glfw.Mods) void {
	if (action == .press) {
		mousePressed(window, button);
	}
}

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
	defer _ = gpa.deinit();

	// If Tracy is enabled, pass-through all allocations to it
	var tracyAlloc = @import("tracy_allocator.zig").TracyAllocator.init(gpa.allocator());
	const allocator = if (tracy.enabled) tracyAlloc.allocator() else gpa.allocator();
	tracy.InitThread();

	try glfw.init(.{});
	defer glfw.terminate();

	var window = try glfw.Window.create(1280, 720, "Stella Dei", null, null, .{
		.opengl_profile = .opengl_core_profile,
		.context_version_major = 4,
		.context_version_minor = 6,
	});
	defer window.destroy();
	window.setCursorPosCallback(cursorPosCallback);
	window.setMouseButtonCallback(mouseButtonCallback);
	window.setScrollCallback(mouseScroll);

	try glfw.makeContextCurrent(window);
	try gl.load({}, getProcAddress);

	renderer = try Renderer.init(allocator, window);
	defer renderer.deinit();
	
	var loop = EventLoop.init();

	loop.beginEvent(); // begin main() event to avoid the loop stopping too soon
	defer loop.endEvent();
	try loop.start(allocator);
	game = try Game.init(allocator, window, &renderer, &loop);
	
	// Start with main menu
	// To see the code, look in src/states/main_menu.zig
	nosuspend game.setState(MainMenuState);
	defer game.deinit();

	var updateLoopJob = try Job(void).create(&loop);
	defer {
		// 'await' without making the function async
		while (!updateLoopJob.isCompleted()) {
			std.atomic.spinLoopHint();
		}
		updateLoopJob.deinit();
	}
	try updateLoopJob.call(updateLoop, .{ &loop, window });

	while (!window.shouldClose()) {
		try glfw.makeContextCurrent(window);
		render(window);

		try window.swapBuffers();
		try glfw.pollEvents();
		tracy.FrameMark();
	}
}

const expect = std.testing.expect;

test "main menu state" {
	var testGame = Game.init();
	try expect(std.meta.activeTag(testGame.state) == .MainMenu);

	testGame.setState(PlayState);
	try expect(std.meta.activeTag(testGame.state) == .Playing);
}
