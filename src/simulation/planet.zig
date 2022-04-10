const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const tracy = @import("../vendor/tracy.zig");

const perlin = @import("../perlin.zig");

const Lifeform = @import("life.zig").Lifeform;

const Vec3 = za.Vec3;

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
	vbo: gl.GLuint,

	numTriangles: gl.GLint,
	numSubdivisions: usize,
	allocator: std.mem.Allocator,
	/// The *unmodified* vertices of the icosphere
	vertices: []Vec3,
	indices: []gl.GLuint,
	/// Slice changed during each upload() call, it contains the data
	/// that will be stored in the VBO.
	bufData: []f32,
	
	waterElevation: []f32,
	elevation: []f32,
	/// Temperature measured in Kelvin
	temperature: []f32,
	/// Buffer array that is used to store the temperatures to be used after next update
	newTemperature: []f32,
	newWaterElevation: []f32,
	lifeforms: std.ArrayList(Lifeform),

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
		const zone = tracy.ZoneN(@src(), "Generate planet");
		defer zone.End();

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
		const waterElev      = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const temperature    = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const newTemp        = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const newWaterElev   = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
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
				waterElev[i / 3] = std.math.max(0, value - 1);
				temperature[i / 3] = (perlin.p2do(theta * 10 + 1, phi * 10 + 1, 6) + 1) * 300; // 0°C
				//temperature[i/3] = 300;
				vertices[i / 3] = point;
				
				// Clear the neighbour list
				for (vertNeighbours[i/3]) |*elem| elem.* = std.math.maxInt(u32);
			}
		}

		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(isize, subdivided.?.indices.len * @sizeOf(f32)), subdivided.?.indices.ptr, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32)));
		gl.vertexAttribPointer(1, 1, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @intToPtr(?*anyopaque, 3 * @sizeOf(f32)));
		gl.vertexAttribPointer(2, 1, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @intToPtr(?*anyopaque, 4 * @sizeOf(f32)));
		gl.enableVertexAttribArray(0);
		gl.enableVertexAttribArray(1);
		gl.enableVertexAttribArray(2);

		return Planet {
			.vao = vao,
			.vbo = vbo,
			.numTriangles = @intCast(gl.GLint, subdivided.?.indices.len),
			.numSubdivisions = numSubdivisions,
			.allocator = allocator,
			.vertices = vertices,
			.verticesNeighbours = vertNeighbours,
			.indices = subdivided.?.indices,
			.elevation = elevation,
			.waterElevation = waterElev,
			.newWaterElevation = newWaterElev,
			.temperature = temperature,
			.newTemperature = newTemp,
			.bufData = try allocator.alloc(f32, vertices.len * 5),
			.lifeforms = std.ArrayList(Lifeform).init(allocator),
		};
	}

	/// Upload all changes to the GPU
	pub fn upload(self: Planet) void {
		const zone = tracy.ZoneN(@src(), "Planet GPU Upload");
		defer zone.End();
		
		// TODO: as it's reused for every upload, just pre-allocate bufData
		const bufData = self.bufData;

		for (self.vertices) |point, i| {
			const elevCoeff: f32 = if (self.temperature[i] <= 273.15) 0.9 else 1.0;
			const transformedPoint = point.norm().scale(self.elevation[i] + (self.waterElevation[i] * elevCoeff));
			bufData[i*5+0] = transformedPoint.x();
			bufData[i*5+1] = transformedPoint.y();
			bufData[i*5+2] = transformedPoint.z();
			bufData[i*5+3] = self.temperature[i];
			bufData[i*5+4] = self.waterElevation[i];
			//bufData[i*5+4] = 0;
		}
		
		gl.bindVertexArray(self.vao);
		gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
		gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, bufData.len * @sizeOf(f32)), bufData.ptr, gl.STREAM_DRAW);
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

	// Note: If pre-computed, this is an highly parallelizable task
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

			// The original points of the icosahedron
			if (candidates.len == 5) {
				candidates.appendAssumeCapacity(idx);
			}

			for (candidates.constSlice()) |neighbour, int| {
				self.verticesNeighbours[idx][int] = @intCast(u32, neighbour);
			}
			// TODO: account for the requested direction
			return candidates.get(directionInt);
		} else {
			return self.verticesNeighbours[idx][directionInt];
		}
	}

	pub const SimulationOptions = struct {
		sunPower: f32,
		conductivity: f32,
		/// Currently, time scale greater than 1 may result in lots of bugs
		timeScale: f32 = 1,
	};

	pub fn simulate(self: *Planet, solarVector: Vec3, options: SimulationOptions) void {
		const zone = tracy.ZoneN(@src(), "Simulate planet");
		defer zone.End();

		const newTemp = self.newTemperature;
		// Fill newTemp with the current temperatures
		for (self.vertices) |_, i| {
			newTemp[i] = std.math.max(0, self.temperature[i]); // temperature may never go below 0°K
		}

		// Do the heat simulation
		for (self.vertices) |vert, i| {
			// Temperature in the current cell
			const temp = self.temperature[i];
			@prefetch(&self.temperature.ptr[i+1], .{ .locality = 0 });

			const solarIllumination = std.math.max(0, vert.dot(solarVector) * options.sunPower * options.timeScale);

			// TODO: maybe follow a logarithmic distribution?
			const radiation = std.math.min(1, temp / 3000 * options.timeScale);

			// TODO: conductivity depends on water level
			const factor = 6 / options.conductivity / options.timeScale;
			const shared = temp / factor;
			newTemp[self.getNeighbour(i, .ForwardLeft)] += shared;
			newTemp[self.getNeighbour(i, .ForwardRight)] += shared;
			newTemp[self.getNeighbour(i, .BackwardLeft)] += shared;
			newTemp[self.getNeighbour(i, .BackwardRight)] += shared;
			newTemp[self.getNeighbour(i, .Left)] += shared;
			newTemp[self.getNeighbour(i, .Right)] += shared;
			newTemp[i] += solarIllumination - radiation - (shared * 6);
		}

		// const dt = 0.1;
		// for (self.vertices) |vert, i| {
		// 	const alpha = 1.15; // thermal diffusivity
		// 	conduct(&self, newTemp, self.temperature[i], self.getNeighbour(i, .ForwardLeft));
		// 	conduct(&self, newTemp, self.temperature[i], self.getNeighbour(i, .ForwardRight));
		// 	conduct(&self, newTemp, self.temperature[i], self.getNeighbour(i, .BackwardLeft));
		// 	conduct(&self, newTemp, self.temperature[i], self.getNeighbour(i, .BackwardRight));
		// 	conduct(&self, newTemp, self.temperature[i], self.getNeighbour(i, .Left));
		// 	conduct(&self, newTemp, self.temperature[i], self.getNeighbour(i, .Right));
		// }

		// Finish by swapping the new temperature
		std.mem.swap([]f32, &self.temperature, &self.newTemperature);

		var iteration: usize = 0;
		while (iteration < 2) : (iteration += 1) {
			const newElev = self.newWaterElevation;
			std.mem.copy(f32, newElev, self.waterElevation);

			// Do some liquid simulation
			for (self.vertices) |_, i| {
				// only fluid if it's not ice
				if (self.temperature[i] > 273.15 or true) {
					const height = self.waterElevation[i];
					const totalHeight = self.elevation[i] + height;

					const factor = 6 / 0.5 / options.timeScale;
					const elevCoeff: f32 = if (self.temperature[i] <= 273.15) 0.9 else 1.0;
					var shared = (height * elevCoeff) / factor;
					var numShared: f32 = 0;

					numShared += self.sendWater(self.getNeighbour(i, .ForwardLeft), shared, totalHeight);
					numShared += self.sendWater(self.getNeighbour(i, .ForwardRight), shared, totalHeight);
					numShared += self.sendWater(self.getNeighbour(i, .BackwardLeft), shared, totalHeight);
					numShared += self.sendWater(self.getNeighbour(i, .BackwardRight), shared, totalHeight);
					numShared += self.sendWater(self.getNeighbour(i, .Left), shared, totalHeight);
					numShared += self.sendWater(self.getNeighbour(i, .Right), shared, totalHeight);
					newElev[i] -= numShared;
				}
			}

			std.mem.swap([]f32, &self.waterElevation, &self.newWaterElevation);
		}
		// std.log.info("water elevation at 123: {d}", .{ newElev[123] });
	}

	fn sendWater(self: Planet, target: usize, shared: f32, totalHeight: f32) f32 {
		const elevCoeff: f32 = if (self.temperature[target] <= 273.15) 0.9 else 1.0;
		if (totalHeight > self.elevation[target] * elevCoeff) {
			var transmitted = std.math.min(1, shared * (totalHeight - self.elevation[target] * elevCoeff) * 10);
			self.newWaterElevation[target] += transmitted;
			return transmitted;
		} else {
			return 0;
		}
	}

	pub fn deinit(self: Planet) void {
		self.lifeforms.deinit();
		self.allocator.free(self.bufData);

		self.allocator.free(self.elevation);
		self.allocator.free(self.newWaterElevation);
		self.allocator.free(self.waterElevation);
		self.allocator.free(self.newTemperature);
		self.allocator.free(self.temperature);
		
		self.allocator.free(self.verticesNeighbours);
		self.allocator.free(self.vertices);
		self.allocator.free(self.indices);
	}

};
