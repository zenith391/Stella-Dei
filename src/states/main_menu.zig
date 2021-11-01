const std = @import("std");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const MouseButton = @import("../glfw.zig").MouseButton;

pub const MainMenuState = struct {

	pub fn init(_: *Game) MainMenuState {
		return MainMenuState {};
	}

	pub fn render(_: *MainMenuState, _: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;

		renderer.drawTexture("sun", size.x / 2 - 125, 50, 250, 250, 0);

		// play button
		renderer.fillRect(size.x / 2 - 200, size.y - 200, 400, 100, 0);
	}

	pub fn mousePressed(_: *MainMenuState, game: *Game, button: MouseButton) void {
		if (button == .Right) {
			game.setState(@import("play.zig").PlayState);
		}
	}

};
