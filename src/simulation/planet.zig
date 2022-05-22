const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const tracy = @import("../vendor/tracy.zig");
const cl = @cImport({
	@cInclude("CL/cl.h");
});

const perlin = @import("../perlin.zig");
const EventLoop = @import("../loop.zig").EventLoop;
const Job = @import("../loop.zig").Job;

const Lifeform = @import("life.zig").Lifeform;

const Vec3 = za.Vec3;
const Allocator = std.mem.Allocator;

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

pub const CLContext = struct {
	device: cl.cl_device_id,
	queue: cl.cl_command_queue,
	simulationKernel: cl.cl_kernel,

	// Memory buffers
	temperatureBuffer: cl.cl_mem,
	newTemperatureBuffer: cl.cl_mem,
	verticesBuffer: cl.cl_mem,
	heatCapacityBuffer: cl.cl_mem,
	verticesNeighbourBuffer: cl.cl_mem,

	pub fn init(allocator: Allocator, self: *const Planet) !CLContext {
		var platform: cl.cl_platform_id = undefined;
		if (cl.clGetPlatformIDs(1, &platform, null) != cl.CL_SUCCESS) {
			return error.OpenCLError;
		}

		var device: cl.cl_device_id = undefined;
		if (cl.clGetDeviceIDs(platform, cl.CL_DEVICE_TYPE_GPU, 1, &device, null) != cl.CL_SUCCESS) {
			return error.OpenCLError;
		}

		const context = cl.clCreateContext(null, 1, &device, null, null, null);
		const queue = cl.clCreateCommandQueue(context, device, 0, null);

		var sources = [_][*c]const u8 { @embedFile("../simulation/simulation.cl") };
		const program = cl.clCreateProgramWithSource(
			context, 1, @ptrCast([*c][*c]const u8, &sources), null, null
		).?;

		// TODO: use SPIR-V for the kernel?
		const buildError = cl.clBuildProgram(program, 1, &device, "-cl-fast-relaxed-math", null, null);
		if (buildError != cl.CL_SUCCESS) {
			std.log.err("error building opencl program: {d}", .{ buildError });

			const log = try allocator.alloc(u8, 16384);
			defer allocator.free(log);
			var size: usize = undefined;
			_ = cl.clGetProgramBuildInfo(program, device, cl.CL_PROGRAM_BUILD_LOG,
				log.len, log.ptr, &size);
			std.debug.print("{s}", .{ log[0..size] });
			return error.OpenCLError;
		}
		const temperatureKernel = cl.clCreateKernel(program, "simulateTemperature", null) orelse return error.OpenCLError;

		const temperatureBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_WRITE | cl.CL_MEM_USE_HOST_PTR,
			self.temperature.len * @sizeOf(f32), self.temperature.ptr, null);
		const newTemperatureBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_WRITE | cl.CL_MEM_USE_HOST_PTR,
			self.newTemperature.len * @sizeOf(f32), self.newTemperature.ptr, null);
		const verticesBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_ONLY | cl.CL_MEM_USE_HOST_PTR,
			self.vertices.len * @sizeOf(Vec3), self.vertices.ptr, null);
		const heatCapacityBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_ONLY | cl.CL_MEM_USE_HOST_PTR,
			self.heatCapacityCache.len * @sizeOf(Vec3), self.heatCapacityCache.ptr, null);
		const verticesNeighbourBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_ONLY | cl.CL_MEM_USE_HOST_PTR,
			self.verticesNeighbours.len * @sizeOf([6]u32), self.verticesNeighbours.ptr, null);

		return CLContext {
			.device = device,
			.queue = queue,
			.simulationKernel = temperatureKernel,

			.temperatureBuffer = temperatureBuffer,
			.newTemperatureBuffer = newTemperatureBuffer,
			.verticesBuffer = verticesBuffer,
			.heatCapacityBuffer = heatCapacityBuffer,
			.verticesNeighbourBuffer = verticesNeighbourBuffer,
		};
	}
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
	/// Original pointer to self.temperature,
	/// this is used for sync up with OpenCL kernels
	temperaturePtrOrg: [*]f32,
	/// Cache of the heat capacity for each point, this just used for
	/// speeding up computations at the expense of some RAM
	/// Unit: J.K-1
	heatCapacityCache: []f32,
	vegetation: []f32,
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

	/// Is null if OpenCL could not be used.
	clContext: ?CLContext = null,

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
		const numPoints = subdivided.?.vertices.len / 3; // number of points
		const vertices       = try allocator.alloc(Vec3,   numPoints);
		const vertNeighbours = try allocator.alloc([6]u32, numPoints);
		const elevation      = try allocator.alloc(f32,    numPoints);
		const waterElev      = try allocator.alloc(f32,    numPoints);
		const temperature    = try allocator.alloc(f32,    numPoints);
		const vegetation     = try allocator.alloc(f32,    numPoints);
		const newTemp        = try allocator.alloc(f32,    numPoints);
		const newWaterElev   = try allocator.alloc(f32,    numPoints);
		const heatCapacCache = try allocator.alloc(f32,    numPoints);

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
			.temperaturePtrOrg = temperature.ptr,
			.vegetation = vegetation,
			.newTemperature = newTemp,
			.heatCapacityCache = heatCapacCache,
			.lifeforms = std.ArrayList(Lifeform).init(allocator),
			.bufData = try allocator.alloc(f32, vertices.len * 9),
			.normals = try allocator.alloc(Vec3, vertices.len),
			.transformedPoints = try allocator.alloc(Vec3, vertices.len),
		};

		planet.clContext = CLContext.init(allocator, &planet) catch blk: {
			std.log.warn("Your system doesn't support OpenCL.", .{});
			break :blk null;
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
				vegetation[i / 3] = perlin.p3do(point.x() + zOffset, point.y() + yOffset, point.z() + xOffset, 4) / 2 + 0.5;

				const totalElevation = elevation[i / 3] + waterElev[i / 3];
				const transformedPoint = point.scale(totalElevation);
				planet.transformedPoints[i / 3] = transformedPoint;
			}
		}
		zone3.End();

		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(isize, subdivided.?.indices.len * @sizeOf(f32)), subdivided.?.indices.ptr, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 9 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32))); // position
		gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 9 * @sizeOf(f32), @intToPtr(?*anyopaque, 3 * @sizeOf(f32))); // normal
		gl.vertexAttribPointer(2, 1, gl.FLOAT, gl.FALSE, 9 * @sizeOf(f32), @intToPtr(?*anyopaque, 6 * @sizeOf(f32))); // temperature (used for a bunch of things)
		gl.vertexAttribPointer(3, 1, gl.FLOAT, gl.FALSE, 9 * @sizeOf(f32), @intToPtr(?*anyopaque, 7 * @sizeOf(f32))); // water level (used in Normal display mode)
		gl.vertexAttribPointer(4, 1, gl.FLOAT, gl.FALSE, 9 * @sizeOf(f32), @intToPtr(?*anyopaque, 8 * @sizeOf(f32))); // vegetation level (temporary until replaced by actual living vegetation)
		gl.enableVertexAttribArray(0);
		gl.enableVertexAttribArray(1);
		gl.enableVertexAttribArray(2);
		gl.enableVertexAttribArray(3);
		gl.enableVertexAttribArray(4);

		// Pre-compute the neighbours of every point of the ico-sphere.
		computeNeighbours(&planet);

		const meanPointArea = (4 * std.math.pi * radius * radius) / @intToFloat(f32, numPoints);
		std.debug.print("There are {d} points in the ico-sphere.\n", .{ numPoints });
		std.debug.print("The mean area per point of the ico-sphere is {d} km²\n", .{ meanPointArea });

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

		// This could be speeded up by using LOD? (allowing to transfer less data)
		// NOTE: this has really bad cache locality
		const STRIDE = 9;
		for (self.vertices) |point, i| {
			const totalElevation = self.elevation[i] + self.waterElevation[i];
			const exaggeratedElev = (totalElevation - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius;
			const transformedPoint = point.scale(exaggeratedElev);
			const normal = self.normals[i];
			self.transformedPoints[i] = transformedPoint;

			bufData[i*STRIDE+0] = transformedPoint.x();
			bufData[i*STRIDE+1] = transformedPoint.y();
			bufData[i*STRIDE+2] = transformedPoint.z();
			bufData[i*STRIDE+3] = normal.x();
			bufData[i*STRIDE+4] = normal.y();
			bufData[i*STRIDE+5] = normal.z();
			bufData[i*STRIDE+6] = self.temperature[i];
			bufData[i*STRIDE+7] = self.waterElevation[i];
			bufData[i*STRIDE+8] = self.vegetation[i];
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

	pub const SimulationOptions = extern struct {
		solarConstant: f32,
		conductivity: f32,
		gameTime: f64,
		/// Currently, time scale greater than 40000 may result in lots of bugs
		timeScale: f32 = 1,
		solarVector: Vec3,
	};

	/// Much cheaper function than std.math.exp
	/// It deviates a lot when x > 25
	fn approxExp(x: f32) f32 {
		std.debug.assert(x <= 0);
		return 1 / (-x + 1);
	}
	// const exp = std.math.exp;
	const exp = approxExp;

	/// Given the index of a point on the planet, compute the specific heat capacity
	inline fn computeHeatCapacity(self: *Planet, pointIndex: usize, pointArea: f32) f32 {
		// specific heat capacities of given materials
		const groundCp: f32 = 700;
		// TODO: more precise water specific heat capacity, depending on temperature
		const waterCp: f32 = if (self.temperature[pointIndex] > 273.15) 4184 else 2093;

		const waterLevel = self.waterElevation[pointIndex];
		const specificHeatCapacity = exp(-waterLevel/20) * (groundCp - waterCp) + waterCp; // J/K/kg
		// Earth is about 5513 kg/m³ (https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html) and assume each point is 0.72m thick??
		const pointMass = pointArea * 0.74 * 5513; // kg
		const heatCapacity = specificHeatCapacity * pointMass; // J.K-1
		return heatCapacity;
	}

	fn simulateTemperature(self: *Planet, loop: *EventLoop, options: SimulationOptions, start: usize, end: usize) void {
		@setFloatMode(.Optimized);
		loop.yield();
		const zone = tracy.ZoneN(@src(), "Temperature Simulation");
		defer zone.End();
		const newTemp = self.newTemperature;
		const heatCapacityCache = self.heatCapacityCache;
		const solarVector = options.solarVector;

		// Number of seconds that passes in 1 simulation step
		const dt = 1.0 / 60.0 * options.timeScale;

		// The surface of the planet (approx.) divided by the numbers of points
		const meanPointArea = (4 * std.math.pi * (self.radius * 1000) * (self.radius * 1000)) / @intToFloat(f32, self.vertices.len); // m²
		// The mean distance between points (note: a little lower than the actual mean
		// due to the fact the point's area aren't squares)
		const meanDistance = std.math.sqrt(meanPointArea); // m

		// The mean surface of a point multiplied by dt
		// This is used as an optimization, to compute this value only once
		const meanPointAreaTime = meanPointArea * dt; // m².s

		{
			var i: usize = start;
			// Pre-compute the heat capacity of each point
			while (i < end) : (i += 1) {
				heatCapacityCache[i] = self.computeHeatCapacity(i, meanPointArea);
			}
		}

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
			const thermalConductivity = exp(-waterLevel/2) * (groundThermalConductivity - waterThermalConductivity) + waterThermalConductivity; // W.m-1.K-1
			const heatCapacity = heatCapacityCache[i];

			var totalTemperatureGain: f32  = 0;

			for (self.getNeighbours(i)) |neighbourIndex| {
				// We compute the 1-dimensional gradient of T (temperature)
				// aka T1 - T2
				const dT = self.temperature[neighbourIndex] - temp;
				if (dT < 0) {
					// Heat transfer only happens from the hot point to the cold one

					// Rate of heat flow density
					const qx = -thermalConductivity * dT / meanDistance; // W.m-2
					//const watt = qx * meanPointArea; // W = J.s-1
					// So, we get heat transfer in J
					//const heatTransfer = watt * dt;
					const heatTransfer = qx * meanPointAreaTime;

					const neighbourHeatCapacity = heatCapacityCache[neighbourIndex];
					// it is assumed neighbours are made of the exact same materials
					// as this point
					const temperatureGain = heatTransfer / neighbourHeatCapacity; // K
					newTemp[neighbourIndex] += temperatureGain;
					totalTemperatureGain -= temperatureGain;
				}
			}

			// Solar irradiance
			{
				const solarCoeff = std.math.max(0, vert.dot(solarVector) / vert.length());
				// TODO: Direct Normal Irradiance? when we have atmosphere
				//const solarIrradiance = options.solarConstant * solarCoeff * meanPointArea; // W = J.s-1
				// So, we get heat transfer in J
				//const heatTransfer = solarIrradiance * dt;
				const heatTransfer = options.solarConstant * solarCoeff * meanPointAreaTime;
				const temperatureGain = heatTransfer / heatCapacity; // K
				totalTemperatureGain += temperatureGain;
			}

			// Thermal radiation with Stefan-Boltzmann law
			{
				const stefanBoltzmannConstant = 0.00000005670374; // W.m-2.K-4
				// water emissivity: 0.96
				// limestone emissivity: 0.92
				const emissivity = 0.93; // took a value between the two
				const radiantEmittance = stefanBoltzmannConstant * temp * temp * temp * temp * emissivity; // W.m-2
				const heatTransfer = radiantEmittance * meanPointAreaTime; // J
				const temperatureLoss = heatTransfer / heatCapacity; // K
				totalTemperatureGain -= temperatureLoss;
			}
			newTemp[i] += totalTemperatureGain;
		}
	}

	fn simulateTemperature_OpenCL(self: *Planet, ctx: CLContext, options: SimulationOptions, start: usize, end: usize) void {
		if (start != 0 or end != self.temperature.len) {
			std.debug.todo("Allow simulateTemperature_OpenCL to have a custom range");
		}

		const zone = tracy.ZoneN(@src(), "Simulate temperature (OpenCL)");
		defer zone.End();

		// Number of seconds that passes in 1 simulation step
		const dt = 1.0 / 60.0 * options.timeScale;

		// The surface of the planet (approx.) divided by the numbers of points
		const meanPointArea = (4 * std.math.pi * (self.radius * 1000) * (self.radius * 1000)) / @intToFloat(f32, self.vertices.len); // m²
		// The mean distance between points (note: a little lower than the actual mean
		// due to the fact the point's area aren't squares)
		const meanDistance = std.math.sqrt(meanPointArea); // m

		// The mean surface of a point multiplied by dt
		// This is used as an optimization, to compute this value only once
		const meanPointAreaTime = meanPointArea * dt; // m².s

		{
			const zone2 = tracy.ZoneN(@src(), "Compute heat capacity");
			defer zone2.End();
			var i: usize = 0;
			// Pre-compute the heat capacity of each point
			while (i < self.temperature.len) : (i += 1) {
				self.heatCapacityCache[i] = self.computeHeatCapacity(i, meanPointArea);
			}
		}

		if (self.temperature.ptr == self.temperaturePtrOrg) {
			_ = cl.clSetKernelArg(ctx.simulationKernel, 0, @sizeOf(cl.cl_mem), &ctx.temperatureBuffer);
			_ = cl.clSetKernelArg(ctx.simulationKernel, 1, @sizeOf(cl.cl_mem), &ctx.newTemperatureBuffer);
		} else {
			_ = cl.clSetKernelArg(ctx.simulationKernel, 1, @sizeOf(cl.cl_mem), &ctx.temperatureBuffer);
			_ = cl.clSetKernelArg(ctx.simulationKernel, 0, @sizeOf(cl.cl_mem), &ctx.newTemperatureBuffer);
		}

		_ = cl.clSetKernelArg(ctx.simulationKernel, 2, @sizeOf(cl.cl_mem), &ctx.verticesBuffer);
		_ = cl.clSetKernelArg(ctx.simulationKernel, 3, @sizeOf(cl.cl_mem), &ctx.heatCapacityBuffer);
		_ = cl.clSetKernelArg(ctx.simulationKernel, 4, @sizeOf(cl.cl_mem), &ctx.verticesNeighbourBuffer);
		_ = cl.clSetKernelArg(ctx.simulationKernel, 5, @sizeOf(f32), &meanPointAreaTime);
		_ = cl.clSetKernelArg(ctx.simulationKernel, 6, @sizeOf(f32), &meanDistance);
		_ = cl.clSetKernelArg(ctx.simulationKernel, 7, @sizeOf(SimulationOptions), &options);

		// TODO: combine with CPU for even faster results!
		const zone2 = tracy.ZoneN(@src(), "Run kernel");
		defer zone2.End();

		// TODO: ceil the global work size
		const global_work_size = (end - start + 511) / 512;
		const kernelError = cl.clEnqueueNDRangeKernel(
			ctx.queue, ctx.simulationKernel, 1,
			null, &global_work_size, null,
			0, null, null
		);
		if (kernelError != cl.CL_SUCCESS) {
			std.log.err("Error running kernel: {d}", .{ kernelError });
			std.os.exit(1);
		}
		_ = cl.clFinish(ctx.queue);
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
				var height = self.newWaterElevation[i];
				// boiling
				// TODO: more accurate
				if (self.temperature[i] > 373.15) {
					height = std.math.max(
						0, height - 0.33
					);
				}

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
				newElev[i] = height - numShared;
			}
		}
	}

	pub fn simulate(self: *Planet, loop: *EventLoop, options: SimulationOptions) void {
		//const zone = tracy.ZoneN(@src(), "Simulate planet");
		//defer zone.End();

		const newTemp = self.newTemperature;
		// Fill newTemp with the current temperatures
		// NOTE: we can copy using memcpy if another way to avoid negative values is found
		for (self.vertices) |_, i| {
			newTemp[i] = std.math.max(0, self.temperature[i]); // temperature may never go below 0°K
		}

		// TODO: mix both
		if (self.clContext) |clContext| {
			self.simulateTemperature_OpenCL(clContext, options, 0, self.temperature.len);
		} else {
			var jobs: [32]@Frame(simulateTemperature) = undefined;
			const parallelness = std.math.min(loop.getParallelCount(), jobs.len);
			const pointCount = self.vertices.len;
			var i: usize = 0;
			while (i < parallelness) : (i += 1) {
				const start = pointCount / parallelness * i;
				const end = if (i == parallelness-1) pointCount else pointCount / parallelness * (i + 1);
				jobs[i] = async self.simulateTemperature(loop, options, start, end);
			}

			i = 0;
			while (i < parallelness) : (i += 1) {
				await jobs[i];
			}
		}

		// Finish by swapping the new temperature
		std.mem.swap([]f32, &self.temperature, &self.newTemperature);

		// TODO: re-do water simulation using Navier-Stokes equations
		if (true) {
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

		{
			// TODO: better
			const zone = tracy.ZoneN(@src(), "Vegetation Simulation");
			defer zone.End();
			
			var i: usize = 0;
			while (i < self.vertices.len) : (i += 1) {
				const vegetation = self.vegetation[i];
				if (self.waterElevation[i] >= 0.1) {
					self.vegetation[i] = std.math.max(0, vegetation - 0.00001 * options.timeScale);
				}
				if (self.temperature[i] >= 273.15 + 50.0 or self.temperature[i] <= 273.15 - 5.0) {
					self.vegetation[i] = std.math.max(0, vegetation - 0.0000001 * options.timeScale);
				}

				for (self.getNeighbours(i)) |neighbour| {
					if (self.waterElevation[neighbour] < 0.1) {
						self.vegetation[neighbour] = std.math.clamp(
							self.vegetation[neighbour] + vegetation * 0.00000001 * options.timeScale, 0, 1
						);
					}
				}
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
		self.allocator.free(self.vegetation);
		self.allocator.free(self.heatCapacityCache);
		
		self.allocator.free(self.verticesNeighbours);
		self.allocator.free(self.vertices);
		self.allocator.free(self.indices);
	}

};
