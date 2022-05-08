const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const tracy = @import("../vendor/tracy.zig");

const perlin = @import("../perlin.zig");
const EventLoop = @import("../loop.zig").EventLoop;
const Job = @import("../loop.zig").Job;

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
	radius: f32,
	allocator: std.mem.Allocator,
	/// The *unmodified* vertices of the icosphere
	vertices: []Vec3,
	indices: []gl.GLuint,
	/// Slice changed during each upload() call, it contains the data
	/// that will be stored in the VBO.
	bufData: []f32,
	/// Normals are computed every 10 frames to avoid overloading CPU for
	/// not much
	normals: []Vec3,
	/// self.vertices transformed by upload(), for easy use by functions like
	/// getNearestPointTo()
	transformedPoints: []Vec3,
	normalComputeJob: ?*Job(void) = null,
	/// The number of time upload() has been called, this is used to keep track
	/// of when to update the normals
	uploadNo: u32 = 0,

	/// The water elevation (TODO: replace with something better?)
	/// Unit: Kilometer
	waterElevation: []f32,
	/// The elevation of each point.
	/// Unit: Kilometer
	elevation: []f32,
	/// Temperature measured
	/// Unit: Kelvin
	temperature: []f32,
	/// Buffer array that is used to store the temperatures to be used after next update
	newTemperature: []f32,
	newWaterElevation: []f32,
	lifeforms: std.ArrayList(Lifeform),
	/// Lock used to avoid concurrent reads and writes to lifeforms arraylist
	lifeformsLock: std.Thread.Mutex = .{},

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

	fn appendNeighbor(planet: *Planet, idx: u32, neighbor: u32) void {
		// Find the next free slot in the list:
		var i: usize = 0;
		while (i < 6) : (i += 1) {
			if(planet.verticesNeighbours[idx][i] == idx) {
				planet.verticesNeighbours[idx][i] = neighbor;
				return;
			} else if(planet.verticesNeighbours[idx][i] == neighbor) {
				return; // The neighbor was already added.
			}
		}
		unreachable;
	}

	fn computeNeighbours(planet: *Planet) void {
		const zone = tracy.ZoneN(@src(), "Compute points neighbours");
		defer zone.End();

		const indices = planet.indices;
		const vertNeighbours = planet.verticesNeighbours;
		var i: u32 = 0;
		// Clear the vertex list:
		while (i < vertNeighbours.len) : (i += 1) {
			var j: u32 = 0;
			while (j < 6) : (j += 1) {
				vertNeighbours[i][j] = i;
			}
		}

		// Loop through all triangles
		i = 0;
		while (i < indices.len) : (i += 3) {
			const aIdx = indices[i+0];
			const bIdx = indices[i+1];
			const cIdx = indices[i+2];
			appendNeighbor(planet, aIdx, bIdx);
			appendNeighbor(planet, aIdx, cIdx);
			appendNeighbor(planet, bIdx, aIdx);
			appendNeighbor(planet, bIdx, cIdx);
			appendNeighbor(planet, cIdx, aIdx);
			appendNeighbor(planet, cIdx, bIdx);
		}
	}

	/// Note: the data is allocated using the event loop's allocator
	pub fn generate(allocator: std.mem.Allocator, numSubdivisions: usize, radius: f32, seed: u32) !Planet {
		const zone = tracy.ZoneN(@src(), "Generate planet");
		defer zone.End();

		const zone2 = tracy.ZoneN(@src(), "Subdivide ico-sphere");
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
		zone2.End();

		const zone3 = tracy.ZoneN(@src(), "Initialise with data");
		const vertices       = try allocator.alloc(Vec3, subdivided.?.vertices.len / 3);
		const vertNeighbours = try allocator.alloc([6]u32, subdivided.?.vertices.len / 3);
		const elevation      = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const waterElev      = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const temperature    = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const newTemp        = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		const newWaterElev   = try allocator.alloc(f32, subdivided.?.vertices.len / 3);
		
		var planet = Planet {
			.vao = vao,
			.vbo = vbo,
			.numTriangles = @intCast(gl.GLint, subdivided.?.indices.len),
			.numSubdivisions = numSubdivisions,
			.radius = radius,
			.allocator = allocator,
			.vertices = vertices,
			.verticesNeighbours = vertNeighbours,
			.indices = subdivided.?.indices,
			.elevation = elevation,
			.waterElevation = waterElev,
			.newWaterElevation = newWaterElev,
			.temperature = temperature,
			.newTemperature = newTemp,
			.lifeforms = std.ArrayList(Lifeform).init(allocator),
			.bufData = try allocator.alloc(f32, vertices.len * 8),
			.normals = try allocator.alloc(Vec3, vertices.len),
			.transformedPoints = try allocator.alloc(Vec3, vertices.len),
		};

		{
			var i: usize = 0;
			const vert = subdivided.?.vertices;
			defer allocator.free(vert);
			const xOffset = @intToFloat(f32, (seed ^ 0xc0ffee11) >> 16) * 14;
			const yOffset = @intToFloat(f32, (seed ^ 0xdeadbeef) & 0xFFFF) * 14;
			const zOffset = @intToFloat(f32, (@floatToInt(u32, xOffset + yOffset) ^ 0xcafebabe) & 0xFFFF);
			std.log.info("seed 0x{x} -> noise offset: {d}, {d}, {d}", .{ seed, xOffset, yOffset, zOffset });
			while (i < vert.len) : (i += 3) {
				var point = Vec3.fromSlice(vert[i..]);
				const value = radius + perlin.p3do(point.x() * 3 + xOffset, point.y() * 3 + yOffset, point.z() * 3 + zOffset, 4) * std.math.min(radius / 2, 15);

				elevation[i / 3] = value;
				waterElev[i / 3] = std.math.max(0, radius - value);
				temperature[i / 3] = 303.15;
				vertices[i / 3] = point.norm();
			}
		}
		zone3.End();

		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(isize, subdivided.?.indices.len * @sizeOf(f32)), subdivided.?.indices.ptr, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32))); // position
		gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, 3 * @sizeOf(f32))); // normal
		gl.vertexAttribPointer(2, 1, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, 6 * @sizeOf(f32))); // temperature (used for a bunch of things)
		gl.vertexAttribPointer(3, 1, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, 7 * @sizeOf(f32))); // water level (used in Normal display mode)
		gl.enableVertexAttribArray(0);
		gl.enableVertexAttribArray(1);
		gl.enableVertexAttribArray(2);
		gl.enableVertexAttribArray(3);

		// Pre-compute the neighbours of every point of the ico-sphere.
		computeNeighbours(&planet);

		return planet;
	}

	const HEIGHT_EXAGGERATION_FACTOR = 25;

	fn computeNormal(self: Planet, a: usize, aVec: Vec3) Vec3 {
		@setFloatMode(.Optimized);
		var sum = Vec3.zero();
		const adjacentVertices = self.getNeighbours(a);
		{
			var i: usize = 1;
			while (i < adjacentVertices.len) : (i += 1) {
				const b = adjacentVertices[i-1];
				const bVec = self.vertices[b].scale((self.elevation[b] + self.waterElevation[b] - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius);
				const c = adjacentVertices[ i ];
				const cVec = self.vertices[c].scale((self.elevation[c] + self.waterElevation[c] - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius);
				var normal = bVec.sub(aVec).cross(cVec.sub(aVec)); // (b-a) x (c-a)
				// if the normal is pointing inside
				const aVecTranslate = aVec.add(normal.norm());
				if (aVecTranslate.dot(aVecTranslate) < aVec.dot(aVec)) {
					normal = normal.negate(); // invert the normal
				}
				sum = sum.add(normal);
			}
		}
		return sum.norm();
	}

	pub fn computeAllNormals(self: *Planet, loop: *EventLoop) void {
		loop.yield();
		const zone = tracy.ZoneN(@src(), "Compute normals");
		defer zone.End();

		// there could potentially be a data race between this function and upload
		// but it's not a problem as even if only a part of a normal's components are
		// updated, the glitch is barely noticeable
		for (self.vertices) |point, i| {
			self.normals[i] = self.computeNormal(i, point.scale((self.elevation[i] + self.waterElevation[i] - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius));
		}
	}

	/// Upload all changes to the GPU
	pub fn upload(self: *Planet, loop: *EventLoop) void {
		@setFloatMode(.Optimized);
		const zone = tracy.ZoneN(@src(), "Planet GPU Upload");
		defer zone.End();
		
		const bufData = self.bufData;
		defer self.uploadNo += 1;
		if (self.normalComputeJob) |job| {
			if (job.isCompleted()) {
				job.deinit();
				self.normalComputeJob = null;
			}
		}
		if (self.uploadNo % 10 == 0 and self.normalComputeJob == null) {
			const job = Job(void).create(loop) catch unreachable;
			self.normalComputeJob = job;
			job.call(computeAllNormals, .{ self, loop }) catch unreachable;
		}

		// NOTE: this has really bad cache locality
		for (self.vertices) |point, i| {
			const totalElevation = self.elevation[i] + self.waterElevation[i];
			const exaggeratedElev = (totalElevation - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius;
			const transformedPoint = point.scale(exaggeratedElev);
			const normal = self.normals[i];
			self.transformedPoints[i] = transformedPoint;

			bufData[i*8+0] = transformedPoint.x();
			bufData[i*8+1] = transformedPoint.y();
			bufData[i*8+2] = transformedPoint.z();
			bufData[i*8+3] = normal.x();
			bufData[i*8+4] = normal.y();
			bufData[i*8+5] = normal.z();
			bufData[i*8+6] = self.temperature[i];
			bufData[i*8+7] = self.waterElevation[i];
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

	pub inline fn getNeighbour(self: Planet, idx: usize, direction: Direction) usize {
		const directionInt = @enumToInt(direction);
		return self.verticesNeighbours[idx][directionInt];
	}

	pub inline fn getNeighbours(self: Planet, idx: usize) [6]usize {
		return [6]usize {
			self.getNeighbour(idx, .ForwardLeft),
			self.getNeighbour(idx, .BackwardLeft),
			self.getNeighbour(idx, .Left),
			self.getNeighbour(idx, .ForwardRight),
			self.getNeighbour(idx, .BackwardRight),
			self.getNeighbour(idx, .Right),
		};
	}

	pub fn getNearestPointTo(self: Planet, position: Vec3) usize {
		// TODO: add a BSP for much better performance?
		var closestPointDist: f32 = std.math.inf_f32;
		var closestPoint: usize = undefined;
		for (self.transformedPoints) |point, i| {
			const distance = point.distance(position);
			if (distance < closestPointDist) {
				closestPoint = i;
				closestPointDist = distance;
			}
		}
		return closestPoint;
	}

	pub const SimulationOptions = struct {
		solarConstant: f32,
		conductivity: f32,
		gameTime: f64,
		/// Currently, time scale greater than 40000 may result in lots of bugs
		timeScale: f32 = 1,
	};

	// TODO: replace std.math.exp by a cheaper approximation

	/// Given the index of a point on the planet, compute the specific heat capacity
	fn computeHeatCapacity(self: *Planet, pointIndex: usize, pointArea: f32) f32 {
		// specific heat capacities of given materials
		const groundCp: f32 = 700;
		// TODO: more precise water specific heat capacity, depending on temperature
		const waterCp: f32 = if (self.temperature[pointIndex] > 273.15) 4184 else 2093;

		const waterLevel = self.waterElevation[pointIndex];
		const specificHeatCapacity = std.math.exp(-waterLevel/20) * (groundCp - waterCp) + waterCp; // J/K/kg
		// Earth is about 5513 kg/m³ (https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html) and assume each point is 0.72m thick??
		const pointMass = pointArea * 0.72 * 5513; // kg
		const heatCapacity = specificHeatCapacity * pointMass; // J.K-1
		return heatCapacity;
	}

	fn simulateTemperature(self: *Planet, loop: *EventLoop, solarVector: Vec3, options: SimulationOptions, start: usize, end: usize) void {
		loop.yield();
		const zone = tracy.ZoneN(@src(), "Temperature Simulation");
		defer zone.End();
		const newTemp = self.newTemperature;

		// Number of seconds that passes in 1 simulation step
		const dt = 1.0 / 60.0 * options.timeScale;

		// The surface of the planet (approx.) divided by the numbers of points
		const meanPointArea = (4 * std.math.pi * (self.radius * 1000) * (self.radius * 1000)) / @intToFloat(f32, self.vertices.len);
		//std.log.debug("Mean point area: {d} km²", .{ meanPointArea / 1_000_000 });

		var i: usize = start;
		// NEW(TM) heat simulation
		while (i < end) : (i += 1) {
			const vert = self.vertices[i];
			// Temperature in the current cell
			const temp = self.temperature[i];

			// In W.m-1.K-1, this is 1 assuming 100% of planet is SiO2 :/
			const groundThermalConductivity: f32 = 1;
			const waterThermalConductivity: f32 = 0.6089;
			const waterLevel = self.waterElevation[i];
			const thermalConductivity = std.math.exp(-waterLevel/2) * (groundThermalConductivity - waterThermalConductivity) + waterThermalConductivity; // W.m-1.K-1
			const heatCapacity = self.computeHeatCapacity(i, meanPointArea);

			inline for (std.meta.fields(Planet.Direction)) |directionField| {
				const neighbourDirection = @intToEnum(Planet.Direction, directionField.value);
				const neighbourIndex = self.getNeighbour(i, neighbourDirection);

				const neighbourPos = self.vertices[neighbourIndex];
				const dP = neighbourPos.sub(vert); // delta position

				// dx will be the distance to the point
				// * 1000 is to convert from km to m
				const dx = dP.length() * 1000;

				// We compute the 1-dimensional gradient of T (temperature)
				// aka T1 - T2
				const dT = self.temperature[neighbourIndex] - temp;
				if (dT < 0) {
					// Heat transfer only happens from the hot point to the cold one

					// Rate of heat flow density
					const qx = -thermalConductivity * dT / dx; // W.m-2
					const watt = qx * meanPointArea; // W = J.s-1
					// So, we get heat transfer in J
					const heatTransfer = watt * dt;

					const neighbourHeatCapacity = self.computeHeatCapacity(neighbourIndex, meanPointArea);
					// it is assumed neighbours are made of the exact same materials
					// as this point
					const temperatureGain = heatTransfer / neighbourHeatCapacity; // K
					newTemp[neighbourIndex] += temperatureGain;
					newTemp[i] -= temperatureGain;
				}
			}

			// Solar irradiance
			{
				const solarCoeff = std.math.max(0, vert.dot(solarVector) / vert.length());
				// TODO: Direct Normal Irradiance? when we have atmosphere
				const solarIrradiance = options.solarConstant * solarCoeff * meanPointArea; // W = J.s-1
				// So, we get heat transfer in J
				const heatTransfer = solarIrradiance * dt;
				const temperatureGain = heatTransfer / heatCapacity; // K
				newTemp[i] += temperatureGain;
			}

			// Thermal radiation with Stefan-Boltzmann law
			{
				const stefanBoltzmannConstant = 0.00000005670374; // W.m-2.K-4
				// water emissivity: 0.96
				// limestone emissivity: 0.92
				const emissivity = 0.93; // took a value between the two
				const radiantEmittance = stefanBoltzmannConstant * temp * temp * temp * temp * emissivity; // W.m-2
				const heatTransfer = radiantEmittance * meanPointArea * dt; // J
				const temperatureLoss = heatTransfer / heatCapacity; // K
				newTemp[i] -= temperatureLoss;
			}
		}
	}
	
	fn simulateWater(self: *Planet, loop: *EventLoop, options: SimulationOptions, numIterations: usize, start: usize, end: usize) void {
		loop.yield();
		const zone = tracy.ZoneN(@src(), "Water Simulation");
		defer zone.End();
		const newElev = self.newWaterElevation;
		
		// Do some liquid simulation
		var i: usize = start;
		while (i < end) : (i += 1) {
			// only fluid if it's not ice
			if (self.temperature[i] > 273.15 or true) {
				const height = self.waterElevation[i];
				const totalHeight = self.elevation[i] + height;

				const factor = 6 / options.timeScale;
				var shared = height / factor / 10000 / @intToFloat(f32, numIterations);
				if (shared > height/2) {
					// TODO: increase step size
					shared = height/2;
				}
				var numShared: f32 = 0;
				std.debug.assert(self.waterElevation[i] >= 0);

				numShared += self.sendWater(self.getNeighbour(i, .ForwardLeft), shared, totalHeight);
				numShared += self.sendWater(self.getNeighbour(i, .ForwardRight), shared, totalHeight);
				numShared += self.sendWater(self.getNeighbour(i, .BackwardLeft), shared, totalHeight);
				numShared += self.sendWater(self.getNeighbour(i, .BackwardRight), shared, totalHeight);
				numShared += self.sendWater(self.getNeighbour(i, .Left), shared, totalHeight);
				numShared += self.sendWater(self.getNeighbour(i, .Right), shared, totalHeight);
				newElev[i] -= numShared;
			}
		}
	}

	pub fn simulate(self: *Planet, loop: *EventLoop, solarVector: Vec3, options: SimulationOptions) void {
		//const zone = tracy.ZoneN(@src(), "Simulate planet");
		//defer zone.End();

		const newTemp = self.newTemperature;
		// Fill newTemp with the current temperatures
		for (self.vertices) |_, i| {
			newTemp[i] = std.math.max(0, self.temperature[i]); // temperature may never go below 0°K
		}

		{
			var jobs: [32]@Frame(simulateTemperature) = undefined;
			const parallelness = std.math.min(loop.getParallelCount(), jobs.len);
			const pointCount = self.vertices.len;
			var i: usize = 0;
			while (i < parallelness) : (i += 1) {
				const start = pointCount / parallelness * i;
				const end = if (i == parallelness-1) pointCount else pointCount / parallelness * (i + 1);
				jobs[i] = async self.simulateTemperature(loop, solarVector, options, start, end);
			}

			i = 0;
			while (i < parallelness) : (i += 1) {
				await jobs[i];
			}
		}

		// Finish by swapping the new temperature
		std.mem.swap([]f32, &self.temperature, &self.newTemperature);

		var iteration: usize = 0;
		var numIterations: usize = 1 + @floatToInt(usize, options.timeScale / 5000);
		while (iteration < numIterations) : (iteration += 1) {
			const newElev = self.newWaterElevation;
			std.mem.copy(f32, newElev, self.waterElevation);

			{
				var jobs: [32]@Frame(simulateWater) = undefined;
				const parallelness = std.math.min(loop.getParallelCount(), jobs.len);
				const pointCount = self.vertices.len;
				var i: usize = 0;
				while (i < parallelness) : (i += 1) {
					const start = pointCount / parallelness * i;
					const end = if (i == parallelness-1) pointCount else pointCount / parallelness * (i + 1);
					jobs[i] = async self.simulateWater(loop, options, numIterations, start, end);
				}

				i = 0;
				while (i < parallelness) : (i += 1) {
					await jobs[i];
				}
			}

			std.mem.swap([]f32, &self.waterElevation, &self.newWaterElevation);
		}

		{
			const zone = tracy.ZoneN(@src(), "Life Simulation");
			defer zone.End();
			
			self.lifeformsLock.lock();
			defer self.lifeformsLock.unlock();
			for (self.lifeforms.items) |*lifeform, i| {
				if (i >= self.lifeforms.items.len) {
					// A lifeform has been removed and we got over
					// the new size of the ArrayList
					break;
				}
				lifeform.aiStep(self, options);
			}
		}
	}

	fn sendWater(self: Planet, target: usize, shared: f32, totalHeight: f32) f32 {
		const targetTotalHeight = self.elevation[target] + self.waterElevation[target];
		if (totalHeight > targetTotalHeight) {
			var transmitted = std.math.min(shared, shared * (totalHeight - targetTotalHeight) / 50);
			std.debug.assert(transmitted >= 0);
			self.newWaterElevation[target] += transmitted;
			return transmitted;
		} else {
			return 0;
		}
	}

	pub fn deinit(self: Planet) void {
		// wait for pending jobs
		if (self.normalComputeJob) |job| {
			while (!job.isCompleted()) {
				std.atomic.spinLoopHint();
			}
			job.deinit();
		}

		// de-allocate
		self.lifeforms.deinit();
		self.allocator.free(self.bufData);
		self.allocator.free(self.normals);
		self.allocator.free(self.transformedPoints);

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
