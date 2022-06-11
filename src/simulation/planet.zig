const builtin = @import("builtin");
const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const tracy = @import("../vendor/tracy.zig");
const cl = @cImport({
	@cDefine("CL_TARGET_OPENCL_VERSION", "110");
	@cInclude("CL/cl.h");
});

const perlin = @import("../perlin.zig");
const EventLoop = @import("../loop.zig").EventLoop;
const Job = @import("../loop.zig").Job;

const Lifeform = @import("life.zig").Lifeform;

const Vec2 = za.Vec2;
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
		const buildError = cl.clBuildProgram(program, 1, &device,
			"-cl-strict-aliasing -cl-fast-relaxed-math",
			null, null);
		if (buildError != cl.CL_SUCCESS) {
			std.log.err("error building opencl program: {d}", .{ buildError });

			const log = try allocator.alloc(u8, 16384);
			defer allocator.free(log);
			var size: usize = undefined;
			_ = cl.clGetProgramBuildInfo(program, device, cl.CL_PROGRAM_BUILD_LOG,
				log.len, log.ptr, &size);
			std.log.err("{s}", .{ log[0..size] });
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
			self.heatCapacityCache.len * @sizeOf(f32), self.heatCapacityCache.ptr, null);
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

	/// The water mass
	/// Unit: 10⁹ kg
	waterMass: []f32,
	/// The water velocity is a 2D velocity on the plane
	/// of the point that's perpendicular to the sphere
	waterVelocity: []Vec2,
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
	newWaterMass: []f32,
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
	pub fn generate(allocator: std.mem.Allocator, numSubdivisions: usize, radius: f32, seed: u64) !Planet {
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
		const waterVelocity  = try allocator.alloc(Vec2,   numPoints);
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
			.waterMass = waterElev,
			.waterVelocity = waterVelocity,
			.newWaterMass = newWaterElev,
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

		// OpenCL doesn't really work well on Windows (atleast when testing
		// using Wine, it might be a missing DLL problem)
		if (builtin.target.os.tag != .windows) {
 			planet.clContext = CLContext.init(allocator, &planet) catch blk: {
				std.log.warn("Your system doesn't support OpenCL.", .{});
				break :blk null;
			};
		} else {
			planet.clContext = null;
		}

		{
			var i: usize = 0;
			const vert = subdivided.?.vertices;
			defer allocator.free(vert);
			const kmPerWaterMass = planet.getKmPerWaterMass();
			std.log.info("{d} km / water ton", .{ kmPerWaterMass });
			std.log.info("seed 0x{x}", .{ seed });
			perlin.setSeed(seed);
			while (i < vert.len) : (i += 3) {
				var point = Vec3.fromSlice(vert[i..]);
				point = point.norm();
				const value = radius + perlin.p3do(point.x() * 3 + 5, point.y() * 3 + 5, point.z() * 3 + 5, 4) * std.math.min(radius / 2, 15);

				elevation[i / 3] = value;
				waterElev[i / 3] = std.math.max(0, radius - value) / kmPerWaterMass;
				vertices[i / 3] = point;
				vegetation[i / 3] = perlin.p3do(point.x() + 5, point.y() + 5, point.z() + 5, 4) / 2 + 0.5;

				const totalElevation = elevation[i / 3] + waterElev[i / 3];
				const transformedPoint = point.scale(totalElevation);
				planet.transformedPoints[i / 3] = transformedPoint;
			}

			std.mem.set(f32, temperature, 293.15);
			std.mem.set(Vec2, waterVelocity, Vec2.zero());
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
		std.log.info("There are {d} points in the ico-sphere.\n", .{ numPoints });
		std.log.info("The mean area per point of the ico-sphere is {d} km²\n", .{ meanPointArea });

		return planet;
	}

	const HEIGHT_EXAGGERATION_FACTOR = 10;

	fn computeNormal(self: Planet, a: usize, aVec: Vec3) Vec3 {
		@setFloatMode(.Optimized);
		var sum = Vec3.zero();
		const kmPerWaterMass = self.getKmPerWaterMass();
		const adjacentVertices = self.getNeighbours(a);
		{
			var i: usize = 1;
			while (i < adjacentVertices.len) : (i += 1) {
				const b = adjacentVertices[i-1];
				const bVec = self.vertices[b].scale((self.elevation[b] + self.waterMass[b] * kmPerWaterMass - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius);
				const c = adjacentVertices[ i ];
				const cVec = self.vertices[c].scale((self.elevation[c] + self.waterMass[c] * kmPerWaterMass - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius);
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
		const kmPerWaterMass = self.getKmPerWaterMass();

		// there could potentially be a data race between this function and upload
		// but it's not a problem as even if only a part of a normal's components are
		// updated, the glitch is barely noticeable
		for (self.vertices) |point, i| {
			self.normals[i] = self.computeNormal(i, point.scale((self.elevation[i] + self.waterMass[i] * kmPerWaterMass - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius));
		}
	}

	pub fn getKmPerWaterMass(self: Planet) f32 {
		const waterDensity = 1000.0; // kg / m³
		const meanPointArea: f64 = self.getMeanPointArea(); // m²
		const kmPerWaterMass =
				1.0 / waterDensity  // m³ / kg
				/ meanPointArea     // m / kg
				/ 1000.0            // km / kg
				* 1_000_000_000     // km / 10⁹ kg
			;
		return @floatCast(f32, kmPerWaterMass);
	}

	/// Returns the mean point area in m²
	pub inline fn getMeanPointArea(self: Planet) f32 {
		// The surface of the planet (approx.) divided by the numbers of points
		// Computation is in f64 for greater accuracy
		const radius: f64 = self.radius;
		const meanPointArea = (4 * std.math.pi * (radius * 1000) * (radius * 1000)) / @intToFloat(f64, self.vertices.len); // m²
		return @floatCast(f32, meanPointArea);
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

		const kmPerWaterMass = self.getKmPerWaterMass();
		//std.log.info("water: {d} m / kg", .{ kmPerWaterMass * 1000 });

		// This could be speeded up by using LOD? (allowing to transfer less data)
		// NOTE: this has really bad cache locality
		const STRIDE = 9;
		for (self.vertices) |point, i| {
			const waterElevation = self.waterMass[i] * kmPerWaterMass;
			const totalElevation = self.elevation[i] + waterElevation;
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
			bufData[i*STRIDE+7] = waterElevation;
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

		const waterLevel = self.waterMass[pointIndex];
		const specificHeatCapacity = exp(-waterLevel/2_000_000) * (groundCp - waterCp) + waterCp; // J/K/kg
		// Earth is about 5513 kg/m³ (https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html) and assume each point is 0.72m thick??
		const pointMass = pointArea * 0.74 * 5513; // kg
		const heatCapacity = specificHeatCapacity * pointMass; // J.K-1
		return heatCapacity;
	}

	fn simulateTemperature(self: *Planet, loop: *EventLoop, options: SimulationOptions, start: usize, end: usize) void {
		@setFloatMode(.Optimized);
		@setRuntimeSafety(false);

		loop.yield();
		const zone = tracy.ZoneN(@src(), "Temperature Simulation");
		defer zone.End();
		const newTemp = self.newTemperature;
		const heatCapacityCache = self.heatCapacityCache;
		const solarVector = options.solarVector;

		// Number of seconds that passes in 1 simulation step
		const dt = 1.0 / 60.0 * options.timeScale;

		// The surface of the planet (approx.) divided by the numbers of points
		const meanPointArea = self.getMeanPointArea(); // m²
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
			const waterLevel = self.waterMass[i];
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
			//std.debug.todo("Allow simulateTemperature_OpenCL to have a custom range");
			std.debug.panic("TODO", .{});
		}

		const zone = tracy.ZoneN(@src(), "Simulate temperature (OpenCL)");
		defer zone.End();

		// Number of seconds that passes in 1 simulation step
		const dt = 1.0 / 60.0 * options.timeScale;

		// The surface of the planet (approx.) divided by the numbers of points
		const meanPointArea = self.getMeanPointArea(); // m²
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

		const dt = 1.0 / 60.0 * options.timeScale;

		const newMass = self.newWaterMass;
		const meanDistance = std.math.sqrt(self.getMeanPointArea()); // m
		const kmPerWaterMass = self.getKmPerWaterMass(); // km / 10⁹ kg
		_ = meanDistance;
		// {
		// 	const diffusivity = 10.0;
		// 	const a = dt * diffusivity / meanDistance;
		// 	_ = numIterations;

		// 	var k: usize = 0;
		// 	while (k < 20) : (k += 1) {
		// 		var i: usize = start;
		// 		while (i < end) : (i += 1) {
		// 			var mass = self.waterMass[i];// + self.elevation[i] / kmPerWaterMass;
		// 			var numShared: f32 = 0;
		// 			const selfElevation = self.elevation[i]
		// 				+ self.waterMass[i] * kmPerWaterMass;
		// 			for (self.getNeighbours(i)) |neighbourIdx| {
		// 				const neighbourElevation = self.elevation[neighbourIdx]
		// 					+ newMass[neighbourIdx] * kmPerWaterMass;
		// 					_ = neighbourElevation; _ = selfElevation;
		// 				//if (neighbourElevation > selfElevation) {
		// 					mass += a * newMass[neighbourIdx];// + self.elevation[neighbourIdx] / kmPerWaterMass);
		// 					numShared += 1;
		// 				//}
		// 			}
		// 			mass = mass / (1 + numShared * a);
		// 			newMass[i] = mass;// - self.elevation[i] / kmPerWaterMass;
		// 		}
		// 	}
		// }

		const shareFactor = 1 / dt * 2 / (6 * @intToFloat(f32, numIterations));
		
		// Do some liquid simulation
		var i: usize = start;
		while (i < end) : (i += 1) {
			// only fluid if it's not ice
			if (self.temperature[i] > 273.15 or true) {
				var mass = self.newWaterMass[i];
				// boiling
				// TODO: more accurate
				if (self.temperature[i] > 373.15) {
					mass = std.math.max(
						0, mass - 1_000_000_000_000
					);
				}

				const totalHeight = self.elevation[i] + mass * kmPerWaterMass;
				var shared = mass * shareFactor;
				// -1 is to account for rounding errors
				if (shared > mass/7) {
					// TODO: increase step size
					shared = std.math.max(0, mass/7);
				}

				var sharedMass: f32 = 0;
				std.debug.assert(self.waterMass[i] >= 0);
				sharedMass += self.sendWater(self.getNeighbour(i, .ForwardLeft), shared, totalHeight, kmPerWaterMass);
				sharedMass += self.sendWater(self.getNeighbour(i, .ForwardRight), shared, totalHeight, kmPerWaterMass);
				sharedMass += self.sendWater(self.getNeighbour(i, .BackwardLeft), shared, totalHeight, kmPerWaterMass);
				sharedMass += self.sendWater(self.getNeighbour(i, .BackwardRight), shared, totalHeight, kmPerWaterMass);
				sharedMass += self.sendWater(self.getNeighbour(i, .Left), shared, totalHeight, kmPerWaterMass);
				sharedMass += self.sendWater(self.getNeighbour(i, .Right), shared, totalHeight, kmPerWaterMass);
				newMass[i] = mass - sharedMass;
				if (newMass[i] < 0) std.log.info("{d} - {d}, 6 * shared = {d}", .{ mass, sharedMass, shared * 6 });
				std.debug.assert(newMass[i] >= 0);
			}
		}

		// const newElev = self.newWaterMass;

		// const shareFactor = 1 / (6 / options.timeScale * 10000 * @intToFloat(f32, numIterations));
		// const kmPerWaterMass = self.getKmPerWaterMass();
		
		// // Do some liquid simulation
		// var i: usize = start;
		// while (i < end) : (i += 1) {
		// 	// only fluid if it's not ice
		// 	if (self.temperature[i] > 273.15 or true) {
		// 		var mass = self.newWaterMass[i];
		// 		// boiling
		// 		// TODO: more accurate
		// 		if (self.temperature[i] > 373.15) {
		// 			mass = std.math.max(
		// 				0, mass - 0.33
		// 			);
		// 		}

		// 		const totalHeight = self.elevation[i] + mass;
		// 		var shared = mass * shareFactor;
		// 		// -1 is to account for rounding errors
		// 		if (shared > mass/7) {
		// 			// TODO: increase step size
		// 			shared = std.math.max(0, mass/7);
		// 		}
		// 		var numShared: f32 = 0;
		// 		std.debug.assert(self.waterMass[i] >= 0);
		// 		numShared += self.sendWater(self.getNeighbour(i, .ForwardLeft), shared, totalHeight, kmPerWaterMass);
		// 		numShared += self.sendWater(self.getNeighbour(i, .ForwardRight), shared, totalHeight, kmPerWaterMass);
		// 		numShared += self.sendWater(self.getNeighbour(i, .BackwardLeft), shared, totalHeight, kmPerWaterMass);
		// 		numShared += self.sendWater(self.getNeighbour(i, .BackwardRight), shared, totalHeight, kmPerWaterMass);
		// 		numShared += self.sendWater(self.getNeighbour(i, .Left), shared, totalHeight, kmPerWaterMass);
		// 		numShared += self.sendWater(self.getNeighbour(i, .Right), shared, totalHeight, kmPerWaterMass);
		// 		newElev[i] = mass - numShared;
		// 		if (newElev[i] < 0) std.log.info("{d} - {d}", .{ mass, numShared });
		// 		std.debug.assert(newElev[i] >= 0);
		// 	}
		// }
	}

	fn sendWater(self: Planet, target: usize, shared: f32, totalHeight: f32, kmPerWaterMass: f32) f32 {
		const targetTotalHeight = self.elevation[target] + self.waterMass[target] * kmPerWaterMass;
		if (totalHeight > targetTotalHeight) {
			var transmitted = std.math.min(shared, shared * (totalHeight - targetTotalHeight) / 50 / kmPerWaterMass);
			std.debug.assert(transmitted >= 0);
			self.newWaterMass[target] += transmitted;
			return transmitted;
		} else {
			return 0;
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
		if (self.clContext != null and false) {
			const clContext = self.clContext.?;
			self.simulateTemperature_OpenCL(clContext, options, 0, self.temperature.len);
			std.log.info("new temp at 0: {d}", .{ self.newTemperature[0] });
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
		var numIterations: usize = 1;
		while (iteration < numIterations) : (iteration += 1) {
			std.mem.copy(f32, self.newWaterMass, self.waterMass);

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

			std.mem.swap([]f32, &self.waterMass, &self.newWaterMass);
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
				var newVegetation: f32 = vegetation;
				newVegetation -= 0.00001 * options.timeScale * @as(f32, if (self.waterMass[i] >= 1000) 1.0 else 0.0);
				const isInappropriateTemperature = self.temperature[i] >= 273.15 + 50.0 or self.temperature[i] <= 273.15 - 5.0;
				newVegetation -= 0.0000001 * options.timeScale * @as(f32, if (isInappropriateTemperature) 1.0 else 0.0);
				self.vegetation[i] = std.math.max(0, newVegetation);

				for (self.getNeighbours(i)) |neighbour| {
					if (self.waterMass[neighbour] < 0.1) {
						self.vegetation[neighbour] = std.math.clamp(
							self.vegetation[neighbour] + vegetation * 0.00000001 * options.timeScale, 0, 1
						);
					}
				}
			}
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
		self.allocator.free(self.newWaterMass);
		self.allocator.free(self.waterMass);
		self.allocator.free(self.waterVelocity);
		self.allocator.free(self.newTemperature);
		self.allocator.free(self.temperature);
		self.allocator.free(self.vegetation);
		self.allocator.free(self.heatCapacityCache);
		
		self.allocator.free(self.verticesNeighbours);
		self.allocator.free(self.vertices);
		self.allocator.free(self.indices);
	}

};
