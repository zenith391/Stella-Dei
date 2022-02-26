const std   = @import("std");
const gl    = @import("gl");
const glfw  = @import("glfw.zig");
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
	window: *glfw.Window,
	renderer: *Renderer,
	allocator: std.mem.Allocator,

	pub fn init(allocator: std.mem.Allocator, window: *glfw.Window, ptrRenderer: *Renderer) !Game {
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

fn mousePressed(window: glfw.Window, button: glfw.MouseButton) void {
	_ = window;
	inline for (std.meta.fields(GameState)) |field| {
		// if the field is active
		if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
			if (@hasDecl(field.field_type, "mousePressed")) {
				@field(game.state, field.name).mousePressed(&game, button);
				return;
			}
		}
	}
}

fn mouseScroll(window: glfw.Window, yOffset: f64) void {
	_ = window;
	inline for (std.meta.fields(GameState)) |field| {
		// if the field is active
		if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
			if (@hasDecl(field.field_type, "mouseScroll")) {
				@field(game.state, field.name).mouseScroll(&game, yOffset);
				return;
			}
		}
	}
}

fn render(window: glfw.Window) void {
	game.audio.update();

	const size = window.getFramebufferSize();
	gl.viewport(0, 0, size.width, size.height);
	gl.clearColor(0, 0, 0, 1);
	gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT);
	renderer.framebufferSize = za.Vec2.new(@intToFloat(f32, size.width), @intToFloat(f32, size.height));

	const zone = tracy.ZoneN(@src(), "Render");
	defer zone.End();
	inline for (std.meta.fields(GameState)) |field| {
		// if the field is active
		if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
			@field(game.state, field.name).render(&game, &renderer);
		}
	}

	renderer.startUI();
	inline for (std.meta.fields(GameState)) |field| {
		// if the field is active
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

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
	defer _ = gpa.deinit();

	var tracyAlloc = @import("tracy_allocator.zig").TracyAllocator.init(gpa.allocator());
	const allocator = if (tracy.enabled) tracyAlloc.allocator() else gpa.allocator();

	tracy.InitThread();

	try glfw.init();
	defer glfw.deinit();

	var window = try glfw.Window.create();
	window.mousePressed = mousePressed;
	window.mouseScroll = mouseScroll;
	window.initEvents();

	try gl.load({}, glfw.getProcAddress);

	renderer = try Renderer.init(allocator, &window);
	defer renderer.deinit();
	
	game = try Game.init(allocator, &window, &renderer);
	defer game.deinit();
	window.loop(render);
}

const expect = std.testing.expect;

test "main menu state" {
	var testGame = Game.init();
	try expect(std.meta.activeTag(testGame.state) == .MainMenu);

	testGame.setState(PlayState);
	try expect(std.meta.activeTag(testGame.state) == .Playing);
}
