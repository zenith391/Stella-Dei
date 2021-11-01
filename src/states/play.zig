const std = @import("std");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const MouseButton = @import("../glfw.zig").MouseButton;

pub const PlayState = struct {
	rot: f32 = 0,

	pub fn init(_: *Game) PlayState {
		return PlayState {};
	}

	pub fn render(self: *PlayState, _: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;
		renderer.drawTexture("sun", size.x / 2 - 125, size.y / 2 - 125, 250, 250, self.rot);
		self.rot += 1;
	}

	pub fn mousePressed(_: *PlayState, _: *Game, button: MouseButton) void {
		std.log.info("Pressed the {} button", .{ button });
	}

};
