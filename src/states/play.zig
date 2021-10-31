const std = @import("std");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const MouseButton = @import("../glfw.zig").MouseButton;

pub const PlayState = struct {

	pub fn init(_: *Game) PlayState {
		return PlayState {};
	}

	pub fn render(_: *PlayState, _: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;
		renderer.drawTexture("sun", size.x / 2 - 125, 50, 250, 250);
	}

	pub fn mousePressed(_: *PlayState, _: *Game, button: MouseButton) void {
		std.log.info("Pressed the {} button", .{ button });
	}

};
