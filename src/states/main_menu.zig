const std = @import("std");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;

pub const MainMenuState = struct {

	pub fn render(_: *MainMenuState, _: *Game, renderer: *Renderer) void {
		renderer.fillRect(0, 0, 100, 100);
		renderer.fillRect(100, 100, 100, 100);
		renderer.drawTexture("sun", 200, 200, 250, 250);
	}

};
