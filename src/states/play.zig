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

const quadVertices = [_]Vec3 {
	// bottom left
	Vec3.new(-0.5, -0.5, 0.0),
	// top left
	Vec3.new(-0.5,  0.5, 0.0),
	// top right
	Vec3.new( 0.5,  0.5, 0.0),
	// bottom right
	Vec3.new( 0.5, -0.5, 0.0),
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

		// TODO: just make the mesh and optimize it in a later pass
		const vertices = try allocator.alloc(f32, quadVertices.len * 3 * width * height);
		defer allocator.free(vertices);

		const indices = try allocator.alloc(u32, quadIndices.len * width * height);
		defer allocator.free(indices);

		var y: usize = 0;
		while (y < height) : (y += 1) {
			var x: usize = 0;
			while (x < width) : (x += 1) {
				const idx = (y * width + x) * quadVertices.len * 3;
				const fx = @intToFloat(f32, x);
				const fy = @intToFloat(f32, y);
				for (quadVertices) |vert, i| {
					var out = vert;
					out.data[0] += fx;
					out.data[1] += fy;
					if (i == 0) { // bottom left
						out.data[1] += perlin.p2do(fx, fy, 4);
					} else if (i == 1) { // top left
						out.data[1] += perlin.p2do(fx, fy + 1, 4);
					} else if (i == 2) { // top right
						out.data[1] += perlin.p2do(fx + 1, fy + 1, 4);
					} else if (i == 3) { // bottom right
						out.data[1] += perlin.p2do(fx + 1, fy, 4);
					}

					vertices[idx + i*3 + 0] = out.x();
					vertices[idx + i*3 + 1] = out.y();
					vertices[idx + i*3 + 2] = out.z();
				}

				const iidx = (y * width + x) * quadIndices.len;
				const indexOffset = (y * width + x) * 4; // 4 indices used per quad
				for (quadIndices) |index, i| {
					indices[i + iidx] = @intCast(u32, index + indexOffset);
				}
			}
		}

		gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, vertices.len * @sizeOf(f32)), vertices.ptr, gl.STATIC_DRAW);
		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(isize, indices.len * @sizeOf(u32)), indices.ptr, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
		gl.enableVertexAttribArray(0);

		return TerrainMesh { .vao = vao, };
	}
};

pub const Planet = struct {
	vao: gl.GLuint,
	/// Number of points that cover the sphere
	numPoints: usize,

	// See http://extremelearning.com.au/evenly-distributing-points-on-a-sphere/
	pub fn getPoint(numPoints: usize, idx: usize) Vec3 {
		std.debug.assert(idx < numPoints);

		const i = @intToFloat(f32, idx) + 0.5;
		const phi = std.math.acos(1 - 2*i / @intToFloat(f32, numPoints));
		const theta = 2 * std.math.pi * i / std.math.phi;
		return Vec3.new(
			std.math.cos(theta) * std.math.sin(phi),
			std.math.sin(theta) * std.math.sin(phi),
			std.math.cos(phi),
		);
	}

	fn vecCompare(_: void, lhs: Vec3, rhs: Vec3) bool {
		const origin = Vec3.new(0, 1, 0);
		return lhs.distance(origin) < rhs.distance(origin);
	}

	pub fn generate(allocator: std.mem.Allocator, numPoints: usize) !Planet {
		var vao: gl.GLuint = undefined;
		gl.genVertexArrays(1, &vao);
		var vbo: gl.GLuint = undefined;
		gl.genBuffers(1, &vbo);

		gl.bindVertexArray(vao);
		gl.bindBuffer(gl.ARRAY_BUFFER, vbo);

		var points = try std.ArrayList(Vec3).initCapacity(allocator, numPoints);
		defer points.deinit();

		{
			var i: usize = 0;
			while (i < numPoints) : (i += 1) {
				var point = getPoint(numPoints, i);

				const phi = std.math.acos(point.z());
				const theta = std.math.acos(point.x() / std.math.sin(phi));
				const value = perlin.p2do(theta * 10, phi * 10, 4);
				_ = value;
				//point = point.scale(1 + value*0.1);
				points.appendAssumeCapacity(point);
			}
		}

		//std.sort.sort(Vec3, points.items, {}, vecCompare);

		const vertices = try allocator.alloc(f32, 3 * numPoints);
		defer allocator.free(vertices);

		// Do a Delaunay triangulation on the points we just got
		{
			// for (points.items) |point, i| {
			// 	// Index into the vertices array
			// 	const arrayIdx = i * 3;

			// 	vertices[arrayIdx + 0] = point.x() * 5;
			// 	vertices[arrayIdx + 1] = point.y() * 5;
			// 	vertices[arrayIdx + 2] = point.z() * 5;
			// }
			var i: usize = 0;
			while (points.items.len >= 3) {
				const triangleA = points.items[0];
				_ = points.swapRemove(0);

				var triangleBIdx: usize = 0;
				var triangleB: Vec3 = Vec3.new(1000, 1000, 1000);
				for (points.items) |candidate, idx| {
					if (candidate.distance(triangleA) < triangleB.distance(triangleA)) {
						triangleB = candidate;
						triangleBIdx = idx;
					}
				}
				_ = points.swapRemove(triangleBIdx);

				var triangleCIdx: usize = 0;
				var triangleC: Vec3 = Vec3.new(1000, 1000, 1000);
				for (points.items) |candidate, idx| {
					if (candidate.distance(triangleA) + candidate.distance(triangleB) 
						< triangleC.distance(triangleA) + triangleC.distance(triangleB)) {
						triangleC = candidate;
						triangleCIdx = idx;
					}
				}
				_ = points.swapRemove(triangleCIdx);

			 	const arrayIdx = i;
				vertices[arrayIdx + 0] = triangleA.x() * 5;
				vertices[arrayIdx + 1] = triangleA.y() * 5;
				vertices[arrayIdx + 2] = triangleA.z() * 5;

				vertices[arrayIdx + 3] = triangleB.x();
				vertices[arrayIdx + 4] = triangleB.y() * 5;
				vertices[arrayIdx + 5] = triangleB.z() * 5;

				vertices[arrayIdx + 6] = triangleC.x() * 5;
				vertices[arrayIdx + 7] = triangleC.y() * 5;
				vertices[arrayIdx + 8] = triangleC.z() * 5;
				i += 9;
			}
		}

		gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, vertices.len * @sizeOf(f32)), vertices.ptr, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
		gl.enableVertexAttribArray(0);

		return Planet {
			.vao = vao,
			.numPoints = numPoints
		};
	}

};

pub const PlayState = struct {
	rot: f32 = 0,
	cameraPos: Vec3 = Vec3.new(0, -5, 0),
	dragStart: Vec2,
	//terrain: ?TerrainMesh = null,
	planet: ?Planet = null,

	pub fn init(game: *Game) PlayState {
		var i: usize = 0;
		while (i < 10) : (i += 1) {
			std.log.err("{}", .{ Planet.getPoint(10, i) });
		}

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
			self.planet = Planet.generate(game.allocator, 1000) catch unreachable;
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
		gl.drawArrays(gl.TRIANGLES, 0, 1000);
	}

	pub fn mousePressed(self: *PlayState, game: *Game, button: MouseButton) void {
		if (button == .Right) {
			self.dragStart = game.window.getCursorPos();
		}
	}

};
