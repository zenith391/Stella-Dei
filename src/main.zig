const std  = @import("std");
const gl   = @import("gl");
const glfw = @import("glfw.zig");
const za   = @import("zalgebra");

const Renderer = @import("renderer.zig").Renderer;
const Texture = @import("renderer.zig").Texture;

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

	pub fn init() Game {
		return Game { .state = .MainMenu };
	}

	pub fn setState(self: *Game, comptime NewState: type) void {
		var state = NewState.init(self);

		inline for (std.meta.fields(GameState)) |field| {
			if (field.field_type == NewState) {
				self.state = @unionInit(GameState, field.name, state);
				return;
			}
		}
		@compileError(@typeName(NewState) ++ " is not in the GameState union");
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

fn render(window: glfw.Window) void {
	const size = window.getFramebufferSize();
	gl.viewport(0, 0, size.width, size.height);
	gl.clearColor(0, 0, 0, 1);
	gl.clear(gl.COLOR_BUFFER_BIT);

	renderer.framebufferSize = za.Vec2.new(@intToFloat(f32, size.width), @intToFloat(f32, size.height));
	inline for (std.meta.fields(GameState)) |field| {
		// if the field is active
		if (std.mem.eql(u8, @tagName(std.meta.activeTag(game.state)), field.name)) {
			@field(game.state, field.name).render(&game, &renderer);
			return;
		}
	}
}

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
	defer _ = gpa.deinit();
	const allocator = &gpa.allocator;

	try glfw.init();
	defer glfw.deinit();

	var window = try glfw.Window.create();
	window.mousePressed = mousePressed;
	window.initEvents();

	try gl.load({}, glfw.getProcAddress);

	renderer = try Renderer.init(allocator, window);
	defer renderer.deinit();
	
	game = Game.init();
	window.loop(render);
}

const expect = std.testing.expect;

test "main menu state" {
	var testGame = Game.init();
	try expect(std.meta.activeTag(testGame.state) == .MainMenu);

	testGame.setState(PlayState);
	try expect(std.meta.activeTag(testGame.state) == .Playing);
}
