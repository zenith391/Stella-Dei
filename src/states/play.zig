const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");

const perlin = @import("../perlin.zig");

const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const MouseButton = @import("../glfw.zig").MouseButton;

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

pub const PlayState = struct {
	rot: f32 = 0,
	cameraPos: Vec3 = Vec3.new(0, -5, 0),
	dragStart: Vec2 = undefined,

	pub fn init(_: *Game) PlayState {
		return PlayState {};
	}

	pub fn render(self: *PlayState, _: *Game, renderer: *Renderer) void {
		const window = renderer.window;
		const size = renderer.framebufferSize;
		//renderer.drawTexture("sun", size.x / 2 - 125, size.y / 2 - 125, 250, 250, self.rot);
		self.rot += 1;

		if (window.isMousePressed(.Right)) {
			const delta = window.getCursorPos().sub(self.dragStart).scale(1 / 100.0);
			self.cameraPos = self.cameraPos.add(Vec3.new(-delta.x, 0, delta.y));

			self.dragStart = window.getCursorPos();
		}

		const program = renderer.terrainProgram;
		program.use();
		program.setUniformMat4("projMatrix",
			Mat4.perspective(70, size.x / size.y, 0.1, 100.0));

		const target = self.cameraPos.add(Vec3.new(0, 5, 2));
		program.setUniformMat4("viewMatrix",
			Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

		var x: f32 = -5;
		while (x < 10) : (x += 1) {
			var y: f32 = -5;
			while (y < 10) : (y += 1) {
				const z = perlin.p2do(x / 10, y / 10, 4) * 3 + 2.0;

				const modelMatrix = Mat4.recompose(Vec3.new(x, z, y), Vec3.new(90, 0, 0), Vec3.one());
				program.setUniformMat4("modelMatrix",
					modelMatrix);
				gl.bindVertexArray(renderer.quadVao);
				gl.drawArrays(gl.TRIANGLES, 0, 6);
			}
		}
	}

	pub fn mousePressed(self: *PlayState, game: *Game, button: MouseButton) void {
		if (button == .Right) {
			self.dragStart = game.window.getCursorPos();
		}
	}

};
