const std   = @import("std");
const gl    = @import("gl");
const glfw  = @import("glfw");
const za    = @import("zalgebra");
const tracy = @import("vendor/tracy.zig");

const Renderer = @import("renderer.zig").Renderer;
const Texture = @import("renderer.zig").Texture;
const AudioSubsystem = @import("audio.zig").AudioSubsystem;

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
	allocator: std.mem.Allocator,

	pub fn init(allocator: std.mem.Allocator, window: glfw.Window, ptrRenderer: *Renderer) !Game {
		return Game {
			.state = .MainMenu,
			.audio = try AudioSubsystem.init(allocator),
			.window = window,
			.renderer = ptrRenderer,
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
	window.setMouseButtonCallback(mouseButtonCallback);
	window.setScrollCallback(mouseScroll);

	try glfw.makeContextCurrent(window);
	try gl.load({}, getProcAddress);

	renderer = try Renderer.init(allocator, window);
	defer renderer.deinit();
	
	game = try Game.init(allocator, window, &renderer);
	
	// Start with main menu
	// To see the code, look in src/states/main_menu.zig
	game.setState(MainMenuState);
	defer game.deinit();

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
