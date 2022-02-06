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

const quadVertices = [_]f32 {
	// bottom left
	-0.5, -0.5, 0.0,
	// top left
	-0.5,  0.5, 0.0,
	// top right
	 0.5,  0.5, 0.0,
	// bottom right
	 0.5, -0.5, 0.0,
};

const quadIndices = [_]u32 {
	0, 1, 2,
	2, 3, 0
};

const TerrainMesh = struct {
	vao: gl.GLuint,

	pub fn generate(allocator: std.mem.Allocator) !TerrainMesh {
		var vao: gl.GLuint = undefined;
		gl.genVertexArrays(1, &vao);
		var vbo: gl.GLuint = undefined;
		gl.genBuffers(1, &vbo);
		var ebo: gl.GLuint = undefined;
		gl.genBuffers(1, &ebo);

		gl.bindVertexArray(vao);
		gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);

		const width = 10;
		const height = 10;

		const vertices = try allocator.alloc(f32, 2 * 3 * 4 * width * height);
		defer allocator.free(vertices);

		const indices = try allocator.alloc(u32, 6 * width * height);
		defer allocator.free(indices);

		var x: usize = 0;
		while (x < width) : (x += 1) {
			var y: usize = 0;
			while (y < height) : (y += 1) {
				const idx = (y * width + x) * 2 * 3 * 4;
				const fx = @intToFloat(f32, x);
				const fy = @intToFloat(f32, y);
				for (quadVertices) |vert, i| {
					var out = vert;
					if (i % 3 == 0) { // x position
						out += fx;
					} else if (i % 3 == 1) { // y position
						out += fy;
					} else if (i == 1*3-1) { // bottom left
						out = perlin.p2do(fx, fy, 4);
					} else if (i == 2*3-1) { // top left
						out = perlin.p2do(fx, fy + 1, 4);
					} else if (i == 3*3-1) { // top right
						out = perlin.p2do(fx + 1, fy + 1, 4);
					} else if (i == 5*3-1) { // bottom right
						out = perlin.p2do(fx + 1, fy, 4);
					}
					vertices[idx + i] = out;
				}

				const iidx = (y * width + x) * 4;
				for (quadIndices) |index, i| {
					indices[iidx + i] = @intCast(u32, index + iidx);
				}
			}
		}



		gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, vertices.len * @sizeOf(f32)), vertices.ptr, gl.STATIC_DRAW);
		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(isize, indices.len * @sizeOf(u32)), indices.ptr, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
		gl.enableVertexAttribArray(0);

		return TerrainMesh { .vao = vao };
	}
};

pub const PlayState = struct {
	rot: f32 = 0,
	cameraPos: Vec3 = Vec3.new(0, -5, 0),
	dragStart: Vec2 = undefined,
	terrain: ?TerrainMesh = null,

	pub fn init(_: *Game) PlayState {
		return PlayState {};
	}

	pub fn render(self: *PlayState, game: *Game, renderer: *Renderer) void {
		const window = renderer.window;
		const size = renderer.framebufferSize;
		//renderer.drawTexture("sun", size.x / 2 - 125, size.y / 2 - 125, 250, 250, self.rot);
		self.rot += 1;

		if (window.isMousePressed(.Right)) {
			const delta = window.getCursorPos().sub(self.dragStart).scale(1 / 100.0);
			self.cameraPos = self.cameraPos.add(Vec3.new(-delta.x(), 0, delta.y()));

			self.dragStart = window.getCursorPos();
		}

		if (self.terrain == null) {
			// TODO: we shouldn't generate terrain in render()
			self.terrain = TerrainMesh.generate(game.allocator) catch unreachable;
		}
		const terrain = self.terrain.?;

		const program = renderer.terrainProgram;
		program.use();
		program.setUniformMat4("projMatrix",
			Mat4.perspective(70, size.x() / size.y(), 0.1, 100.0));

		const target = self.cameraPos.add(Vec3.new(0, 5, 2));
		program.setUniformMat4("viewMatrix",
			Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

		const modelMatrix = Mat4.recompose(Vec3.new(-5, 2, -5), Vec3.new(90, 0, 0), Vec3.new(1, 1, 1));
		program.setUniformMat4("modelMatrix",
			modelMatrix);

		program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
		gl.bindVertexArray(terrain.vao);
		gl.drawElements(gl.TRIANGLES, 6 * 10 * 10, gl.UNSIGNED_INT, null);
	}

	pub fn mousePressed(self: *PlayState, game: *Game, button: MouseButton) void {
		if (button == .Right) {
			self.dragStart = game.window.getCursorPos();
		}
	}

};
