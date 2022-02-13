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

const icoIndices = &[_]gl.GLuint {
	0, 4, 1, 0, 9, 4, 9, 5, 4, 4, 5, 8, 4, 8, 1, 8, 10, 1, 8, 3, 10, 5, 3, 8,
	5, 2, 3, 2, 7, 3, 7, 10, 3, 7, 6, 10, 7, 11, 6, 11, 0, 6, 0, 1, 6,
	6, 1, 10, 9, 0, 11, 9, 11, 2, 9, 2, 5, 7, 2, 11
};

const IndexPair = struct {
	first: gl.GLuint,
	second: gl.GLuint
};

pub const Planet = struct {
	vao: gl.GLuint,
	numTriangles: gl.GLint,
	numSubdivisions: usize,
	allocator: std.mem.Allocator,
	/// The *unmodified* vertices of the icosphere
	vertices: []Vec3,
	indices: []gl.GLuint,
	
	elevation: []f32,
	/// Temperature measured in Kelvin
	temperature: []f32,
	/// Buffer array that is used to store the temperatures to be used after next update
	newTemperature: []f32,

	// 0xFFFFFFFF in the first entry considered null and not filled
	/// List of neighbours for a vertex. A vertex has 6 neighbours that arrange in hexagons
	/// Neighbours are stored as u32 as icospheres with more than 4 billions vertices aren't worth
	/// supporting.
	verticesNeighbours: [][6]u32,

	const LookupMap = std.AutoHashMap(IndexPair, gl.GLuint);
	fn vertexForEdge(lookup: *LookupMap, vertices: *std.ArrayList(f32), first: gl.GLuint, second: gl.GLuint) !gl.GLuint {
		const a = if (first > second) first  else second;
		const b = if (first > second) second else first;

		const pair = IndexPair { .first = a, .second = b };
		const result = try lookup.getOrPut(pair);
		if (!result.found_existing) {
			result.value_ptr.* = @intCast(gl.GLuint, vertices.items.len / 3);
			const edge0 = Vec3.new(
				vertices.items[a*3+0],
				vertices.items[a*3+1],
				vertices.items[a*3+2],
			);
			const edge1 = Vec3.new(
				vertices.items[b*3+0],
				vertices.items[b*3+1],
				vertices.items[b*3+2],
			);
			const point = edge0.add(edge1).norm();
			try vertices.append(point.x());
			try vertices.append(point.y());
			try vertices.append(point.z());
		}

		return result.value_ptr.*;
	}

	const IndexedMesh = struct {
		vertices: []f32,
		indices: []gl.GLuint
	};

	fn subdivide(allocator: std.mem.Allocator, vertices: []const f32, indices: []const gl.GLuint) !IndexedMesh {
		var lookup = LookupMap.init(allocator);
		defer lookup.deinit();
		var result = std.ArrayList(gl.GLuint).init(allocator);
		var verticesList = std.ArrayList(f32).init(allocator);
		try verticesList.appendSlice(vertices);

		var i: usize = 0;
		while (i < indices.len) : (i += 3) {
			var mid: [3]gl.GLuint = undefined;
			var edge: usize = 0;
			while (edge < 3) : (edge += 1) {
				mid[edge] = try vertexForEdge(&lookup, &verticesList,
					indices[i+edge], indices[i+(edge+1)%3]);
			}

			try result.ensureUnusedCapacity(12);
			result.appendAssumeCapacity(indices[i+0]);
			result.appendAssumeCapacity(mid[0]);
			result.appendAssumeCapacity(mid[2]);

			result.appendAssumeCapacity(indices[i+1]);
			result.appendAssumeCapacity(mid[1]);
			result.appendAssumeCapacity(mid[0]);

			result.appendAssumeCapacity(indices[i+2]);
			result.appendAssumeCapacity(mid[2]);
			result.appendAssumeCapacity(mid[1]);

			result.appendAssumeCapacity(mid[0]);
			result.appendAssumeCapacity(mid[1]);
			result.appendAssumeCapacity(mid[2]);
		}

		return IndexedMesh {
			.vertices = verticesList.toOwnedSlice(),
			.indices = result.toOwnedSlice(),
		};
	}

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
		
		var subdivided: ?IndexedMesh = null;
		{
			var i: usize = 0;
			while (i < numSubdivisions) : (i += 1) {
				const oldSubdivided = subdivided;
				const vert = if (subdivided) |s| s.vertices else icoVertices;
				const indc = if (subdivided) |s| s.indices else icoIndices;
				subdivided = try subdivide(allocator, vert, indc);

				if (oldSubdivided) |s| {
					allocator.free(s.vertices);
					allocator.free(s.indices);
				}
			}
		}

		const vertices       = try allocator.alloc(Vec3, subdivided.?.vertices.len / 3);
		const vertNeighbours = try allocator.alloc([6]u32, subdivided.?.vertices.len / 3);
		const elevation      = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const temperature    = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const newTemp        = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		{
			var i: usize = 0;
			const vert = subdivided.?.vertices;
			defer allocator.free(vert);
			while (i < vert.len) : (i += 3) {
				var point = Vec3.fromSlice(vert[i..]);

				const theta = std.math.acos(point.z());
				const phi = std.math.atan2(f32, point.y(), point.x());
				// TODO: 3D perlin (or simplex) noise for correct looping
				const value = 1 + perlin.p2do(theta * 3 + 74, phi * 3 + 42, 4) * 0.05;

				elevation[i / 3] = value;
				temperature[i / 3] = 273.15; // 0°C
				vertices[i / 3] = point;
				
				// Clear the neighbour list
				for (vertNeighbours[i/3]) |*elem| elem.* = std.math.maxInt(u32);
			}
		}

		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(isize, subdivided.?.indices.len * @sizeOf(f32)), subdivided.?.indices.ptr, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32)));
		gl.vertexAttribPointer(1, 1, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @intToPtr(?*anyopaque, 3 * @sizeOf(f32)));
		gl.enableVertexAttribArray(0);
		gl.enableVertexAttribArray(1);

		return Planet {
			.vao = vao,
			.numTriangles = @intCast(gl.GLint, subdivided.?.indices.len),
			.numSubdivisions = numSubdivisions,
			.allocator = allocator,
			.vertices = vertices,
			.verticesNeighbours = vertNeighbours,
			.indices = subdivided.?.indices,
			.elevation = elevation,
			.temperature = temperature,
			.newTemperature = newTemp,
		};
	}

	/// Upload all changes to the GPU
	pub fn upload(self: Planet) void {
		// TODO: optimise using gl.bufferSubData

		// TODO: as it's reused for every upload, just pre-allocate bufData
		var bufData = self.allocator.alloc(f32, self.vertices.len * 4) catch @panic("out of memory");
		defer self.allocator.free(bufData);

		for (self.vertices) |point, i| {
			const transformedPoint = point.norm().scale(self.elevation[i]);
			bufData[i*4+0] = transformedPoint.x();
			bufData[i*4+1] = transformedPoint.y();
			bufData[i*4+2] = transformedPoint.z();
			bufData[i*4+3] = self.temperature[i];
		}
		
		gl.bindVertexArray(self.vao);
		gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, bufData.len * @sizeOf(f32)), bufData.ptr, gl.STATIC_DRAW);
	}

	/// Get the index to the vertex that is the closest to the given position.
	/// 'pos' is assumed to be normalized.
	pub fn getClosestTo(self: Planet, pos: Vec3) usize {
		var closest: usize = 0;
		var closestDist: f32 = std.math.inf_f32;

		for (self.vertices) |point, i| {
			const dist = point.distance(pos);
			if (dist < closestDist) {
				closest = i;
				closestDist = dist;
			}
		}

		return closest;
	}

	pub const Direction = enum {
		ForwardLeft,
		BackwardLeft,
		Left,
		ForwardRight,
		BackwardRight,
		Right,
	};

	fn contains(list: anytype, element: usize) bool {
		for (list.constSlice()) |item| {
			if (item == element) return true;
		}
		return false;
	}

	pub fn getNeighbour(self: Planet, idx: usize, direction: Direction) usize {
		const directionInt = @enumToInt(direction);

		// This vertex's neighbours weren't found yet
		if (self.verticesNeighbours[idx][directionInt] == std.math.maxInt(u32)) {
			const point = self.vertices[idx];
			var candidates = std.BoundedArray(usize, 6).init(0) catch unreachable;

			// Loop through all triangles
			var i: usize = 0;
			while (i < self.indices.len) : (i += 3) {
				const aIdx = self.indices[i+0];
				const bIdx = self.indices[i+1];
				const cIdx = self.indices[i+2];
				const a = self.vertices[aIdx];
				const b = self.vertices[bIdx];
				const c = self.vertices[cIdx];

				// If one of the triangle's point is what we have, add the other points of the triangle
				if (a.eql(point)) {
					if (!contains(candidates, bIdx)) candidates.appendAssumeCapacity(bIdx); // b
					if (!contains(candidates, cIdx)) candidates.appendAssumeCapacity(cIdx); // c
				} else if (b.eql(point)) {
					if (!contains(candidates, aIdx)) candidates.appendAssumeCapacity(aIdx); // a
					if (!contains(candidates, cIdx)) candidates.appendAssumeCapacity(cIdx); // c
				} else if (c.eql(point)) {
					if (!contains(candidates, aIdx)) candidates.appendAssumeCapacity(aIdx); // a
					if (!contains(candidates, bIdx)) candidates.appendAssumeCapacity(bIdx); // b
				}
			}
			// std.log.debug("{d}: {d} candidates", .{ idx, candidates.len });
			if (candidates.len == 5) {
				// TODO: just fix the bug instead but only the first few vertices seem to have this bug
				candidates.appendAssumeCapacity(idx);
			}

			self.verticesNeighbours[idx][directionInt] = @intCast(u32, candidates.get(directionInt));
			// TODO: account for the requested direction
			return candidates.get(directionInt);
		} else {
			return self.verticesNeighbours[idx][directionInt];
		}
	}

	pub fn deinit(self: Planet) void {
		self.allocator.free(self.elevation);
		self.allocator.free(self.newTemperature);
		self.allocator.free(self.temperature);
		self.allocator.free(self.verticesNeighbours);
		self.allocator.free(self.vertices);
		self.allocator.free(self.indices);
	}

};

pub const PlayState = struct {
	rot: f32 = 0,
	cameraPos: Vec3 = Vec3.new(0, -8, 2),
	dragStart: Vec2,
	planet: ?Planet = null,

	cameraDistance: f32 = 1000,
	targetCameraDistance: f32 = 30,
	displayMode: PlanetDisplayMode = .Normal,

	const PlanetDisplayMode = enum(c_int) {
		Normal = 0,
		Temperature = 1,
	};

	pub fn init(game: *Game) PlayState {
		return PlayState {
			.dragStart = game.window.getCursorPos()
		};
	}

	pub fn render(self: *PlayState, game: *Game, renderer: *Renderer) void {
		const window = renderer.window;
		const size = renderer.framebufferSize;
		// renderer.drawTexture("sun", size.x() / 2 - 125, size.y() / 2 - 125, 250, 250, self.rot);
		// self.rot += 1;

		if (window.isMousePressed(.Right)) {
			const delta = window.getCursorPos().sub(self.dragStart).scale(1 / 100.0);
			const right = self.cameraPos.cross(Vec3.forward()).norm();
			const forward = self.cameraPos.cross(Vec3.right()).norm();
			self.cameraPos = self.cameraPos.add(
				 right.scale(delta.x())
				.add(forward.scale(delta.y()))
				.scale(self.cameraDistance / 5));
			self.dragStart = window.getCursorPos();

			self.cameraPos = self.cameraPos.norm()
				.scale(self.cameraDistance);
		}
		if (!std.math.approxEqAbs(f32, self.cameraDistance, self.targetCameraDistance, 0.01)) {
			self.cameraDistance = self.cameraDistance * 0.9 + self.targetCameraDistance * 0.1;
			self.cameraPos = self.cameraPos.norm()
				.scale(self.cameraDistance);
		}

		if (self.planet == null) {
			// TODO: we shouldn't generate planet in render()
			self.planet = Planet.generate(game.allocator, 4) catch unreachable;
			self.planet.?.upload();
		}
		var planet = &self.planet.?;

		const sunTheta: f32 = @floatCast(f32, @mod(@intToFloat(f64, std.time.milliTimestamp()) / 1000, 2*std.math.pi));
		const sunPhi: f32 = 0.4;
		const solarVector = Vec3.new(
			std.math.cos(sunPhi) * std.math.sin(sunTheta),
			std.math.sin(sunPhi) * std.math.sin(sunTheta),
			std.math.cos(sunTheta)
		);

		const newTemp = planet.newTemperature;
		// Fill newTemp with the current temperatures
		for (planet.vertices) |_, i| {
			newTemp[i] = std.math.max(0, planet.temperature[i]); // temperature may never go below 0°K
		}

		// Do the heat simulation
		for (planet.vertices) |vert, i| {
			// Temperature in the current cell
			const temp = planet.temperature[i];

			const solarIllumination = std.math.max(0, vert.dot(solarVector) * 0.4);

			// TODO: maybe follow a logarithmic distribution?
			const radiation = std.math.min(1, planet.temperature[i] / 3000);

			const conductance = 0.25;
			const factor = 6 / conductance;
			const shared = temp / factor;

			newTemp[planet.getNeighbour(i, .ForwardLeft)] += shared;
			newTemp[planet.getNeighbour(i, .ForwardRight)] += shared;
			newTemp[planet.getNeighbour(i, .BackwardLeft)] += shared;
			newTemp[planet.getNeighbour(i, .BackwardRight)] += shared;
			newTemp[planet.getNeighbour(i, .Left)] += shared;
			newTemp[planet.getNeighbour(i, .Right)] += shared;
			newTemp[i] += solarIllumination - radiation - (shared * 6);
		}

		// Finish by swapping the new temperature
		std.mem.swap([]f32, &planet.temperature, &planet.newTemperature);
		planet.upload();

		const program = renderer.terrainProgram;
		program.use();
		program.setUniformMat4("projMatrix",
			Mat4.perspective(70, size.x() / size.y(), 0.1, 1000.0));
		
		const target = Vec3.new(0, 0, 0);
		program.setUniformMat4("viewMatrix",
			Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

		const modelMatrix = Mat4.recompose(Vec3.new(0, 0, 0), Vec3.new(90, 0, 0), Vec3.new(20, 20, 20));
		program.setUniformMat4("modelMatrix",
			modelMatrix);

		program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
		program.setUniformVec3("lightDir", solarVector);
		program.setUniformInt("displayMode", @enumToInt(self.displayMode)); // display temperature
		gl.bindVertexArray(planet.vao);
		gl.drawElements(gl.TRIANGLES, planet.numTriangles, gl.UNSIGNED_INT, null);
	}

	pub fn mousePressed(self: *PlayState, game: *Game, button: MouseButton) void {
		if (button == .Right) {
			self.dragStart = game.window.getCursorPos();
		}
		if (button == .Middle) {
			if (self.displayMode == .Normal) {
				self.displayMode = .Temperature;
			} else if (self.displayMode == .Temperature) {
				self.displayMode = .Normal;
			}
		}
	}

	pub fn mouseScroll(self: *PlayState, _: *Game, yOffset: f64) void {
		self.targetCameraDistance = std.math.clamp(
			self.targetCameraDistance - @floatCast(f32, yOffset), 21, 100);
	}

	pub fn deinit(self: *PlayState) void {
		if (self.planet) |planet| {
			planet.deinit();
		}
	}

};
