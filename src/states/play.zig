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

const icoX = 0.525731112119133606;
const icoZ = 0.850650808352039932;
const icoVertices = &[_]f32 {
	-icoX, 0,  icoZ,
	 icoX, 0,  icoZ,
	-icoX, 0, -icoZ,
	 icoX, 0, -icoZ,
	0,  icoZ,  icoX,
	0,  icoZ, -icoX,
	0, -icoZ,  icoX,
	0, -icoZ, -icoX,
	 icoZ,  icoX, 0,
	-icoZ,  icoX, 0,
	 icoZ, -icoX, 0,
	-icoZ, -icoX, 0,
};

const icoIndices = &[_]u32 {
	0, 4, 1, 0, 9, 4, 9, 5, 4, 4, 5, 8, 4, 8, 1, 8, 10, 1, 8, 3, 10, 5, 3, 8,
	5, 2, 3, 2, 7, 3, 7, 10, 3, 7, 6, 10, 7, 11, 6, 11, 0, 6, 0, 1, 6,
	6, 1, 10, 9, 0, 11, 9, 11, 2, 9, 2, 5, 7, 2, 11
};

pub const Planet = struct {
	vao: gl.GLuint,
	numTriangles: gl.GLint,

	pub fn generate(allocator: std.mem.Allocator, numSubdivisions: usize) !Planet {
		_ = allocator;
		_ = numSubdivisions;

		var vao: gl.GLuint = undefined;
		gl.genVertexArrays(1, &vao);
		var vbo: gl.GLuint = undefined;
		gl.genBuffers(1, &vbo);
		var ebo: gl.GLuint = undefined;
		gl.genBuffers(1, &ebo);

		gl.bindVertexArray(vao);
		gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);

		gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, icoVertices.len * @sizeOf(f32)), icoVertices, gl.STATIC_DRAW);
		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(isize, icoIndices.len * @sizeOf(f32)), icoIndices, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
		gl.enableVertexAttribArray(0);
		return Planet {
			.vao = vao,
			.numTriangles = icoIndices.len
		};
	}

};

pub const PlayState = struct {
	rot: f32 = 0,
	cameraPos: Vec3 = Vec3.new(0, -5, 0),
	dragStart: Vec2,
	planet: ?Planet = null,

	pub fn init(game: *Game) PlayState {
		return PlayState {
			.dragStart = game.window.getCursorPos()
		};
	}

	pub fn render(self: *PlayState, game: *Game, renderer: *Renderer) void {
		const window = renderer.window;
		const size = renderer.framebufferSize;
		//renderer.drawTexture("sun", size.x() / 2 - 125, size.y() / 2 - 125, 250, 250, self.rot);
		//self.rot += 1;

		if (window.isMousePressed(.Right)) {
			const delta = window.getCursorPos().sub(self.dragStart).scale(1 / 100.0);
			self.cameraPos = self.cameraPos.add(Vec3.new(-delta.x(), 0, delta.y()));
			self.dragStart = window.getCursorPos();
		}

		if (self.planet == null) {
			// TODO: we shouldn't generate planet in render()
			self.planet = Planet.generate(game.allocator, 1) catch unreachable;
		}
		const planet = self.planet.?;

		const program = renderer.terrainProgram;
		program.use();
		program.setUniformMat4("projMatrix",
			Mat4.perspective(70, size.x() / size.y(), 0.1, 100.0));

		const target = self.cameraPos.add(Vec3.new(0, 5, 2));
		program.setUniformMat4("viewMatrix",
			Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

		const modelMatrix = Mat4.recompose(Vec3.new(-2.5, 3, -2.5), Vec3.new(90, 0, 0), Vec3.new(1, 1, 1));
		program.setUniformMat4("modelMatrix",
			modelMatrix);

		program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
		gl.bindVertexArray(planet.vao);
		gl.drawElements(gl.TRIANGLES, planet.numTriangles, gl.UNSIGNED_INT, null);
	}

	pub fn mousePressed(self: *PlayState, game: *Game, button: MouseButton) void {
		if (button == .Right) {
			self.dragStart = game.window.getCursorPos();
		}
	}

};
