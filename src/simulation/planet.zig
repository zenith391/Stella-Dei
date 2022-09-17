const builtin = @import("builtin");
const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const tracy = @import("../vendor/tracy.zig");
const cl = @cImport({
	@cDefine("CL_TARGET_OPENCL_VERSION", "110");
	@cInclude("CL/cl.h");
});

pub const USE_OPENCL = false;

const perlin = @import("../perlin.zig");
const EventLoop = @import("../loop.zig").EventLoop;
const Job = @import("../loop.zig").Job;
const IcosphereMesh = @import("../utils.zig").IcosphereMesh;

const Lifeform = @import("life.zig").Lifeform;

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Allocator = std.mem.Allocator;

pub const CLContext = if (!USE_OPENCL) struct {} else struct {
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
	mesh: IcosphereMesh,
	atmosphereMesh: IcosphereMesh,

	numTriangles: gl.GLint,
	numSubdivisions: usize,
	seed: u64,
	radius: f32,
	/// Arena allocator for simulation data
	simulationArena: std.heap.ArenaAllocator,
	allocator: std.mem.Allocator,
	/// The *unmodified* vertices of the icosphere
	vertices: []Vec3,
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
	/// The mass of water vapor in the troposphere
	/// Unit: 10⁹ kg
	waterVaporMass: []f32,
	/// The average N2 mass per point of the planet
	/// Unit: 10⁹ kg
	averageNitrogenMass: f32 = 0,
	/// The average O2 mass per point of the planet
	/// Unit: 10⁹ kg
	averageOxygenMass: f32 = 0,
	/// The average CO2 mass per point of the planet
	/// Unit: 10⁹ kg
	averageCarbonDioxideMass: f32 = 0,
	/// Historic rainfall
	/// Unit: arbitrary
	rainfall: []f32,
	/// The air velocity is a 2D velocity on the plane
	/// of the point that's tangent to the sphere
	/// Unit: km/s
	airVelocity: []Vec2,
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
	newWaterVaporMass: []f32,
	lifeforms: std.ArrayListUnmanaged(Lifeform),
	/// Lock used to avoid concurrent reads and writes to lifeforms arraylist
	lifeformsLock: std.Thread.Mutex = .{},

	// 0xFFFFFFFF in the first entry considered null and not filled
	/// List of neighbours for a vertex. A vertex has 6 neighbours that arrange in hexagons
	/// Neighbours are stored as u32 as icospheres with more than 4 billions vertices aren't worth
	/// supporting.
	verticesNeighbours: [][6]u32,

	/// Is null if OpenCL could not be used.
	clContext: ?CLContext = null,

	pub const DisplayMode = enum(c_int) {
		Normal = 0,
		Temperature = 1,
		WaterVapor = 2,
		WindMagnitude = 3,
		Rainfall = 4,
	};

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

		const indices = planet.mesh.indices;
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

		const atmosphereMesh = try IcosphereMesh.generate(allocator, numSubdivisions, false);
		gl.bindVertexArray(atmosphereMesh.vao[0]);
		gl.bindBuffer(gl.ARRAY_BUFFER, atmosphereMesh.vbo);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32))); // position
		gl.vertexAttribPointer(1, 1, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @intToPtr(?*anyopaque, 3 * @sizeOf(f32))); // temperature (used for a bunch of things)
		gl.enableVertexAttribArray(0);
		gl.enableVertexAttribArray(1);

		const mesh = try IcosphereMesh.generate(allocator, numSubdivisions, true);

		// ArenaAllocator for all the simulation data points
		var simulationArena = std.heap.ArenaAllocator.init(allocator);
		const simAlloc = simulationArena.allocator();

		const zone3 = tracy.ZoneN(@src(), "Initialise with data");
		const numPoints      = mesh.num_points;
		const vertices       = try simAlloc.alloc(Vec3,   numPoints);
		const vertNeighbours = try simAlloc.alloc([6]u32, numPoints);
		const elevation      = try simAlloc.alloc(f32,    numPoints);
		const waterElev      = try simAlloc.alloc(f32,    numPoints);
		const airVelocity    = try simAlloc.alloc(Vec2,   numPoints);
		const waterVaporMass = try simAlloc.alloc(f32,    numPoints);
		const rainfall       = try simAlloc.alloc(f32,    numPoints);
		const temperature    = try simAlloc.alloc(f32,    numPoints);
		const vegetation     = try simAlloc.alloc(f32,    numPoints);
		const newTemp        = try simAlloc.alloc(f32,    numPoints);
		const newWaterElev   = try simAlloc.alloc(f32,    numPoints);
		const newVaporMass   = try simAlloc.alloc(f32,    numPoints);
		const heatCapacCache = try simAlloc.alloc(f32,    numPoints);

		const lifeforms = try std.ArrayListUnmanaged(Lifeform).initCapacity(simAlloc, 0);
		const bufData = try simAlloc.alloc(f32, vertices.len * 9);
		const normals = try simAlloc.alloc(Vec3, vertices.len);
		const transformedPoints = try simAlloc.alloc(Vec3, vertices.len);

		var planet = Planet {
			.mesh = mesh,
			.atmosphereMesh = atmosphereMesh,
			.numTriangles = @intCast(gl.GLint, mesh.indices.len),
			.numSubdivisions = numSubdivisions,
			.seed = seed,
			.radius = radius,
			.simulationArena = simulationArena,
			.allocator = allocator,
			.vertices = vertices,
			.verticesNeighbours = vertNeighbours,
			.elevation = elevation,
			.waterMass = waterElev,
			.waterVaporMass = waterVaporMass,
			.rainfall = rainfall,
			.airVelocity = airVelocity,
			.newWaterMass = newWaterElev,
			.newWaterVaporMass = newVaporMass,
			.temperature = temperature,
			.temperaturePtrOrg = temperature.ptr,
			.vegetation = vegetation,
			.newTemperature = newTemp,
			.heatCapacityCache = heatCapacCache,
			.lifeforms = lifeforms,
			.bufData = bufData,
			.normals = normals,
			.transformedPoints = transformedPoints,
		};

		// OpenCL doesn't really work well on Windows (atleast when testing
		// using Wine, it might be a missing DLL problem)
		if (builtin.target.os.tag != .windows and USE_OPENCL) {
 			planet.clContext = CLContext.init(allocator, &planet) catch blk: {
				std.log.warn("Your system doesn't support OpenCL.", .{});
				break :blk null;
			};
		} else {
			planet.clContext = null;
		}

		{
			var prng = std.rand.DefaultPrng.init(seed);
			const random = prng.random();

			const vert = mesh.vertices;
			const kmPerWaterMass = planet.getKmPerWaterMass();
			const seaLevel = radius + (random.float(f32) - 0.5) * 10; // between +5km and -5/km

			std.log.info("{d} km / water ton", .{ kmPerWaterMass });
			std.log.info("seed 0x{x}", .{ seed });
			std.log.info("Sea Level: {d} km", .{ seaLevel - radius });
			perlin.setSeed(random.int(u64));
			var i: usize = 0;
			while (i < vert.len) : (i += 3) {
				var point = Vec3.fromSlice(vert[i..]);
				point = point.norm();
				const value = radius + perlin.noise(point.x() * 3 + 5, point.y() * 3 + 5, point.z() * 3 + 5) * std.math.min(radius / 2, 15);

				elevation[i / 3] = value;
				waterElev[i / 3] = std.math.max(0, seaLevel - value) / kmPerWaterMass;
				vertices[i / 3] = point;
				vegetation[i / 3] = perlin.fbm(point.x() + 5, point.y() + 5, point.z() + 5, 4) / 2 + 0.5;

				temperature[i / 3] = (1 - @fabs(point.z())) * 55 + 273.15 - 25.0;

				const totalElevation = elevation[i / 3] + waterElev[i / 3];
				const transformedPoint = point.scale(totalElevation);
				planet.transformedPoints[i / 3] = transformedPoint;
			}

			std.mem.set(f32, waterVaporMass, 0);
			std.mem.set(f32, rainfall, 0);
			std.mem.set(Vec2, airVelocity, Vec2.zero());

			const NITROGEN_PERCENT = 78.084 / 100.0;
			const OXYGEN_PERCENT = 20.946 / 100.0;
			const CARBON_DIOXIDE_PERCENT = 0.6 / 100.0; // estimated value from Earth prebiotic era
			const ATMOSPHERE_MASS = 5.15 * std.math.pow(f64, 10, 18 - 9);
			planet.averageNitrogenMass = @floatCast(f32, NITROGEN_PERCENT * ATMOSPHERE_MASS / @intToFloat(f64, numPoints));
			planet.averageOxygenMass = @floatCast(f32, OXYGEN_PERCENT * ATMOSPHERE_MASS / @intToFloat(f64, numPoints));
			planet.averageCarbonDioxideMass = @floatCast(f32, CARBON_DIOXIDE_PERCENT * ATMOSPHERE_MASS / @intToFloat(f64, numPoints));
		}
		zone3.End();

		// Pre-compute the neighbours of every point of the ico-sphere.
		computeNeighbours(&planet);

		for (mesh.vao) |vao| {
			gl.bindVertexArray(vao);
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
		}

		const meanPointArea = (4 * std.math.pi * radius * radius) / @intToFloat(f32, numPoints);
		std.log.info("There are {d} points in the ico-sphere.\n", .{ numPoints });
		std.log.info("The mean area per point of the ico-sphere is {d} km²\n", .{ meanPointArea });

		return planet;
	}

	const HEIGHT_EXAGGERATION_FACTOR = 10;

	fn computeNormal(self: Planet, a: usize, aVec: Vec3) Vec3 {
		@setFloatMode(.Optimized);
		var sum = Vec3.zero();
		const adjacentVertices = self.getNeighbours(a);
		{
			var i: usize = 1;
			while (i < adjacentVertices.len) : (i += 1) {
				const b = adjacentVertices[i-1];
				const bVec = self.transformedPoints[b];
				const c = adjacentVertices[ i ];
				const cVec = self.transformedPoints[c];
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
		for (self.transformedPoints) |point, i| {
			self.normals[i] = self.computeNormal(i, point);
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

	pub fn mulByVec3(self: za.Mat4, v: Vec3) Vec3 {
		@setFloatMode(.Optimized);
		@setRuntimeSafety(false);

		const x = (self.data[0][0] * v.x()) + (self.data[1][0] * v.y()) + (self.data[2][0] * v.z());
		const y = (self.data[0][1] * v.x()) + (self.data[1][1] * v.y()) + (self.data[2][1] * v.z());
		const z = (self.data[0][2] * v.x()) + (self.data[1][2] * v.y()) + (self.data[2][2] * v.z());
		return Vec3.new(x, y, z);
	}

	/// Upload all changes to the GPU
	pub fn upload(self: *Planet, loop: *EventLoop, displayMode: DisplayMode, axialTilt: f32) void {
		@setFloatMode(.Optimized);
		@setRuntimeSafety(false);

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

		{
			const rotationMatrix = za.Mat4.fromRotation(axialTilt, Vec3.right());
			const kmPerWaterMass = self.getKmPerWaterMass();
			//std.log.info("water: {d} m / kg", .{ kmPerWaterMass * 1000 });

			// This could be speeded up by using LOD? (allowing to transfer less data)
			// NOTE: this has really bad cache locality
			const STRIDE = 9;
			for (self.vertices) |point, i| {
				const waterElevation = self.waterMass[i] * kmPerWaterMass;
				const totalElevation = self.elevation[i] + waterElevation;
				const exaggeratedElev = (totalElevation - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius;
				const scaledPoint = point.scale(exaggeratedElev);
				const transformedPoint = mulByVec3(rotationMatrix, scaledPoint);
				const normal = self.normals[i];
				self.transformedPoints[i] = transformedPoint;

				const bytePos = i * STRIDE;
				const bufSlice = bufData[bytePos+0..bytePos+10];
				bufSlice[0..3].* = transformedPoint.data;
				bufSlice[3..6].* = normal.data;
				bufData[bytePos+6] = switch (displayMode) {
					.WaterVapor => self.waterVaporMass[i],
					.WindMagnitude => self.airVelocity[i].x(),
					.Rainfall => self.rainfall[i],
					else => self.temperature[i]
				};
				bufData[bytePos+7] = if (displayMode == .WindMagnitude) self.airVelocity[i].y() else waterElevation;
				bufData[bytePos+8] = self.vegetation[i];
			}
			
			gl.bindBuffer(gl.ARRAY_BUFFER, self.mesh.vbo);
			gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, bufData.len * @sizeOf(f32)), bufData.ptr, gl.STREAM_DRAW);
		}

		{
			const STRIDE = 4;
			for (self.vertices) |point, i| {
				const transformedPoint = point.scale(self.radius + 15 * HEIGHT_EXAGGERATION_FACTOR);

				const bytePos = i * STRIDE;
				const bufSlice = bufData[bytePos+0..bytePos+4];
				bufSlice[0..3].* = transformedPoint.data;
				bufSlice[   3]   = self.rainfall[i];
			}

			gl.bindBuffer(gl.ARRAY_BUFFER, self.atmosphereMesh.vbo);
			gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, STRIDE * self.atmosphereMesh.num_points * @sizeOf(f32)), bufData.ptr, gl.STREAM_DRAW);
		}
	}

	pub fn render(self: *Planet, loop: *EventLoop, displayMode: DisplayMode, axialTilt: f32) void {
		self.upload(loop, displayMode, axialTilt);
		for (self.mesh.vao) |vao, vaoIdx| {
			gl.bindVertexArray(vao);
			// TODO: use actual number of elements per octant
			gl.drawElements(gl.TRIANGLES, self.mesh.num_elements[vaoIdx], gl.UNSIGNED_INT, null);
		}
	}

	pub fn renderAtmosphere(self: *Planet) void {
		gl.bindVertexArray(self.atmosphereMesh.vao[0]);
		gl.drawElements(gl.TRIANGLES, @intCast(c_int, self.atmosphereMesh.indices.len), gl.UNSIGNED_INT, null);
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
		/// The real time elapsed between two updates
		dt: f32,
		solarConstant: f32,
		planetRotationTime: f32,
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
		tracy.FiberEnter("Simulate temperature");
		defer tracy.FiberLeave();
		const zone = tracy.ZoneN(@src(), "Temperature Simulation");
		defer zone.End();
		const newTemp = self.newTemperature;
		const heatCapacityCache = self.heatCapacityCache;
		const solarVector = options.solarVector;

		// Number of seconds that passes in 1 simulation step
		const dt = options.dt * options.timeScale;

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
			const normVert = self.transformedPoints[i].norm();
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
				const solarCoeff = std.math.max(0, normVert.dot(solarVector) / normVert.length());
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
		if (!USE_OPENCL) @compileError("Not using OpenCL");
		if (start != 0 or end != self.temperature.len) {
			//std.debug.todo("Allow simulateTemperature_OpenCL to have a custom range");
			std.debug.panic("TODO", .{});
		}

		const zone = tracy.ZoneN(@src(), "Simulate temperature (OpenCL)");
		defer zone.End();

		// Number of seconds that passes in 1 simulation step
		const dt = options.dt * options.timeScale;

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

		const dt = options.dt * options.timeScale;

		const newMass = self.newWaterMass;
		const meanPointArea = self.getMeanPointArea();
		const meanDistance = std.math.sqrt(meanPointArea); // m
		const meanDistanceKm = meanDistance / 1000; // km
		const kmPerWaterMass = self.getKmPerWaterMass(); // km / 10⁹ kg
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

		const shareFactor = 0.00002 * dt / (6 * @intToFloat(f32, numIterations));
		const substanceDivider: f64 = self.getSubstanceDivider();
		const meanAtmVolume: f64 = self.getMeanPointArea() * 12_000; // m³
		
		// Do some liquid simulation
		var i: usize = start;
		while (i < end) : (i += 1) {
			// only fluid if it's not ice
			const temp = self.temperature[i];
			if (temp > 273.15 or true) {
				var mass = self.newWaterMass[i];
				// boiling
				// TODO: more accurate
				if (temp > 373.15) {
					const diff = std.math.min(100_000_000, mass);
					mass = mass - diff;
					self.newWaterVaporMass[i] += diff;
				} else {
					// evaporation
					// TODO: more accurate (make it depend on temperature and mass / surface area)
					const RH = Planet.getRelativeHumidity(substanceDivider, temp, self.waterVaporMass[i]);
					// evaporation only happens when the air isn't saturated
					if (RH < 1) {
						const diff = std.math.min(0.01 * dt, mass) * @as(f32, if (temp > 273.15) 1.0 else 0.0);
						mass = mass - diff;
						self.newWaterVaporMass[i] += diff;
					}
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

		// Those are simply the coordinates of points in an hexagon,
		// which is enough to get a (rough approximation of a) tangent
		// vector.
		const tangentVectors = [6]Vec2 {
			Vec2.new(-0.5,  0.9),
			Vec2.new(-0.5, -0.9),
			Vec2.new(-1.0,  0.0),
			Vec2.new( 0.5,  0.9),
			Vec2.new( 0.5, -0.9),
			Vec2.new( 1.0,  0.0),
		};

		// Do some water vapor simulation
		i = start;
		while (i < end) : (i += 1) {
			const mass = self.newWaterVaporMass[i];
			const T = self.temperature[i]; // TODO: separate air temperature?
			const pressure = self.getAirPressure(substanceDivider, T, mass);
			self.rainfall[i] = std.math.max(0, self.rainfall[i] * (1.0 - dt / 86400.0));

			if (false) {
			for (self.getNeighbours(i)) |neighbourIdx, location| {
				const neighbourVapor = self.waterVaporMass[neighbourIdx];
				const dP = pressure - self.getAirPressure(substanceDivider, self.temperature[neighbourIdx], neighbourVapor);
				
				// // Vector corresponding to the right-center point of the tangent plane of the sphere passing through current point
				// const right = transformedPoint.cross(Vec3.back()).norm();

				// // Vector corresponding to the center-up point on the tangent plane
				// const up = transformedPoint.cross(right).norm();

				const tangent = tangentVectors[location];

				// wind is from high pressure to low pressure
				if (dP > 0) {
					// Pressure gradient force
					const pgf = dP / meanDistance * meanAtmVolume; // N
					// F = ma, so a = F/m
					const acceleration = @floatCast(f32, pgf / (mass * 1_000_000_000) / 1000 * dt); // km/s
					self.airVelocity[i].data += tangent.scale(acceleration).data;
				}
			}
			}
			std.debug.assert(self.newWaterVaporMass[i] >= 0);

			// Rainfall
			{
				const RH = Planet.getRelativeHumidity(substanceDivider, T, mass);
				// rain
				if (RH > 0.95 and T < 373.15) {
					// clouds don't go above 15km
					if (self.newWaterMass[i] * kmPerWaterMass + self.elevation[i] - self.radius < 15) {
						// TODO: form cloud as clouds are formed from super-saturated air
						const diff = std.math.min(mass, 0.5 * dt * mass / 100000.0);
						self.newWaterVaporMass[i] -= diff;
						self.newWaterMass[i] += diff;
						self.rainfall[i] += diff / dt * 86400;
					}
				}
			}
		}

		// Do some wind simulation
		i = start;
		if (true) {
		
		// For simplicity, take the viscosity of air at 20°C
		// (see https://en.wikipedia.org/wiki/Viscosity#Air)
		const airViscosity = 2.791 * std.math.pow(f32, 10, -7) * std.math.pow(f32, 273.15 + 20.0, 0.7355); // Pa.s
		const airSpeedMult = 1 - airViscosity;
		const spinRate = 1.0 / options.planetRotationTime * 2 * std.math.pi * self.radius / 500000;
		while (i < end) : (i += 1) {
			const vert = self.vertices[i];
			const transformedPoint = self.transformedPoints[i];
			var velocity = self.airVelocity[i];

			// Coriolis force
			if (true) {
				// TODO: implement branchless?
				var latitude = std.math.acos(vert.z());
				if (latitude > std.math.pi / 2.0) {
					latitude = -latitude;
				}
				// note: velocity is assumed to not be above meanDistanceKm
				velocity = velocity.add(Vec2.new(
					spinRate * 2.0 * @sin(latitude) * dt, 0));
			}

			// Apply drag
			{
				const velocityN = velocity.length() * 10; // * 10 given the square after, so that the result is in km/s while still being the same as if velocity was expressed in m/s in the computation
				const dragCoeff = 1.55;
				const area = meanPointArea / 1000 * (@maximum(0.1, (self.elevation[i] - self.radius) / 10)); // TODO: depend on steepness!!

				// It's supposed to be * kg/m³ but as we divide by kg later, it's faster to directly divide by m³
				const dragForce = 1.0 / 2.0 * velocityN * velocityN * dragCoeff * area / meanPointArea; // * massDensity // TODO: depend on Mach number?
				velocity = velocity.sub(velocity.norm().scale(std.math.clamp(dragForce * dt, 0, velocityN/20)));
			}

			var appliedVelocity = Vec3.new(velocity.x() * dt, velocity.y() * dt, 0);
			if (appliedVelocity.dot(appliedVelocity) > meanDistanceKm * meanDistanceKm) { // length squared > meanDistanceKm²
				appliedVelocity = appliedVelocity.norm().scale(meanDistanceKm);
			}

			// Vector corresponding to the right-center point of the tangent plane of the sphere passing through current point
			const right = transformedPoint.cross(Vec3.back()).norm();

			// Vector corresponding to the center-up point on the tangent plane
			const up = transformedPoint.cross(right).norm();
			const targetPos = transformedPoint.add(
				right.scale(appliedVelocity.x()).add(
				up.scale(appliedVelocity.y()))
			);

			const neighbours = self.getNeighbours(i);
			for (neighbours) |neighbourIdx| {
				const neighbourPos = self.transformedPoints[neighbourIdx];
				const diff = meanDistanceKm - std.math.min(meanDistanceKm, neighbourPos.distance(targetPos));

				const shared = std.math.clamp(diff / (6 * meanDistanceKm), 0, 1);
				//std.log.info("shared: {d}", .{ shared });
				const sharedVapor = self.waterVaporMass[i] * shared;
				self.newWaterVaporMass[neighbourIdx] += sharedVapor;
				// avoid negative values due to imprecision
				self.newWaterVaporMass[i] = std.math.max(0, self.newWaterVaporMass[i] - sharedVapor);
			}
			velocity = velocity.scale(airSpeedMult);

			self.airVelocity[i] = velocity;
		}
		}
	}

	/// Compute partial pressure using ideal gas law, it is done in f64 as
	/// the amount of substance can get very high.
	/// Note: instead of using the gas constant, the Boltzmann constant is directly used
	/// as substanceDivider also accounts for the Avogadro constant (NA)
	pub inline fn getPartialPressure(substanceDivider: f64, temperature: f32, mass: f64) f64 {
		const k = 1.380649 * comptime std.math.pow(f64, 10, -23); // Boltzmann constant
		const waterPartialPressure = (mass * k * temperature) / substanceDivider; // Pa
		return waterPartialPressure;
	}

	/// Returns the mass of all the air above the given point's area, in 10⁹ kg
	pub inline fn getAirMass(self: Planet, idx: usize) f32 {
		// + 1 is because there will never be 0 kg of air (and if it's the case it breaks a bunch of computations)
		return self.waterVaporMass[idx] + self.averageNitrogenMass + self.averageOxygenMass + self.averageCarbonDioxideMass + 1; // + TODO other gases
	}

	pub inline fn getAirPressure(self: Planet, substanceDivider: f64, temperature: f32, vaporMass: f64) f64 {
		return getPartialPressure(substanceDivider, temperature, vaporMass + self.averageNitrogenMass + self.averageOxygenMass + self.averageCarbonDioxideMass + 1);
	}

	/// Returns the pressure that air excerts on a given point, in Pascal.
	pub fn getAirPressureOfPoint(self: Planet, idx: usize) f64 {
		return self.getAirPressure(self.getSubstanceDivider(), self.temperature[idx], self.waterVaporMass[idx]);
	}

	/// Uses Tetens equation
	/// The fact that it is off for below 0°C isn't important as we're doing
	/// quite big approximations anyways
	fn getEquilibriumVaporPressure_Unoptimized(temperature: f32) f32 {
		// TODO: precompute boiling point and then do a lerp between precomputed values
		return 0.61078 * @exp(17.27 * (temperature-273.15) / (temperature + 237.3 - 273.15)) * 1000;
	}

	const equilibriumVaporPressures = blk: {
		const from = 0.0;
		const to = 1000.0;
		const step = 1.0;
		const arrayLength = @floatToInt(usize, (to-from)/step);
		var values: [arrayLength]f32 = undefined;

		@setEvalBranchQuota(arrayLength * 10);
		var x: f32 = from;
		while (x < to) : (x += step) {
			const idx = @floatToInt(usize, x / step);
			values[idx] = getEquilibriumVaporPressure_Unoptimized(x);
			if (std.math.isInf(values[idx])) { // precision error
				values[idx] = 0;
			}
		}
		break :blk values;
	};

	inline fn lerp(a: f32, b: f32, t: f32) f32 {
		@setFloatMode(.Optimized);
		return a * (1 - t) + b * t;
	}

	pub inline fn getEquilibriumVaporPressure(temperature: f32) f32 {
		@setFloatMode(.Optimized);
		if (temperature >= 999) {
			// This shouldn't be possible with default ranges, so no need to optimize
			return getEquilibriumVaporPressure_Unoptimized(temperature);
		} else {
			const idx = @floatToInt(u32, temperature);
			return lerp(equilibriumVaporPressures[idx], equilibriumVaporPressures[idx+1], @rem(temperature, 1));
		}
	}

	pub inline fn getRelativeHumidity(substanceDivider: f64, temperature: f32, mass: f64) f64 {
		return getPartialPressure(substanceDivider, temperature, mass) / getEquilibriumVaporPressure(temperature);
	}

	/// Returns the constant used for computations with the perfect gas law
	pub fn getSubstanceDivider(self: Planet) f64 {
		// The mean atmosphere volume per point is approximately equal
		// to mean point area multiplied by the height of the troposphere (~12km)
		const meanAtmVolume: f64 = self.getMeanPointArea() * 12_000; // m³

		const NA = 6.02214076 * std.math.pow(f64, 10, 23); // NA = 6.02214076 × 10²³
		// Atmospheric volume accounted for amount of substance and 10¹² g units
		const substanceDivider: f64 = meanAtmVolume
			* 18.015 // there are 18.015g in a mole of water
			/ std.math.pow(f64, 10, 12) // water mass is in 10⁹ kg (= 10¹² g)
			/ NA; // account for Avogadro constant
		return substanceDivider;
	}

	fn sendWater(self: Planet, target: usize, shared: f32, totalHeight: f32, kmPerWaterMass: f32) f32 {
		const targetTotalHeight = self.elevation[target] + self.waterMass[target] * kmPerWaterMass;
		if (totalHeight > targetTotalHeight) {
			var transmitted = std.math.min(shared, shared * (totalHeight - targetTotalHeight) / 2 / kmPerWaterMass);
			std.debug.assert(transmitted >= 0);
			self.newWaterMass[target] += transmitted;
			return transmitted;
		} else {
			return 0;
		}
	}

	fn sendWaterVapor(self: Planet, target: usize, shared: f32, selfMass: f32) f32 {
		const targetMass = self.waterVaporMass[target];
		if (selfMass > targetMass) {
			var transmitted = std.math.min(shared, shared * (selfMass - targetMass));
			self.newWaterVaporMass[target] += transmitted;
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
		if (USE_OPENCL and self.clContext != null) {
			const clContext = self.clContext.?;
			self.simulateTemperature_OpenCL(clContext, options, 0, self.temperature.len);
			std.log.info("new temp at 0: {d}", .{ self.newTemperature[0] });
		} else {
			var jobs: [32]@Frame(simulateTemperature) = undefined;
			const parallelness = std.math.min(loop.getParallelCount() * 4, jobs.len);
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

		const dt = options.dt * options.timeScale;
		// Disable water simulation when timescale is above 100 000
		if (dt < 15000) {
			var iteration: usize = 0;
			var numIterations: usize = 1;
			while (iteration < numIterations) : (iteration += 1) {
				std.mem.copy(f32, self.newWaterMass, self.waterMass);
				std.mem.copy(f32, self.newWaterVaporMass, self.waterVaporMass);

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
				std.mem.swap([]f32, &self.waterVaporMass, &self.newWaterVaporMass);
			}
		} else {
			// TODO: use a global water level
			// this can work as high timescales like that should only be possible
			// in the geologic timescale (when plate tectonics still happens)
		}
		
		// Geologic simulation only happens when the time scale is more than 1 year per second
		if (dt > 365 * std.time.ns_per_day) {

		}

		if (options.timeScale < 100000) {
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
		} else {
			// TODO: switch down to much simplified and "globalized" life simulation
		}

		if (options.timeScale < 100000) {
			// TODO: better
			const zone = tracy.ZoneN(@src(), "Vegetation Simulation");
			defer zone.End();
			
			var i: usize = 0;
			while (i < self.vertices.len) : (i += 1) {
				const vegetation = self.vegetation[i];
				const waterMass = self.waterMass[i];
				var newVegetation: f32 = vegetation;
				// vegetation roots can drown in too much water
				newVegetation -= 0.0001 * dt * @as(f32, if (self.waterMass[i] >= 1_000_000) 1.0 else 0.0);
				newVegetation -= 0.0001 * dt * @as(f32, if (self.elevation[i]-self.radius >= 7) 1.0 else 0.0);
				// but it still needs water to grow
				const shareCoeff = @as(f32, if (waterMass >= 10) 1.0 else 0.0);
				newVegetation -= 0.0000001 * dt / 10;
				// TODO: actually consume the water ?

				const isInappropriateTemperature = self.temperature[i] >= 273.15 + 50.0 or self.temperature[i] <= 273.15 - 5.0;
				newVegetation -= 0.000001 * dt * @as(f32, if (isInappropriateTemperature) 1.0 else 0.0);
				self.vegetation[i] = std.math.max(0, newVegetation);

				for (self.getNeighbours(i)) |neighbour| {
					if (self.waterMass[neighbour] < 0.1) {
						self.vegetation[neighbour] = std.math.clamp(
							self.vegetation[neighbour] + vegetation * 0.0000001 * dt * shareCoeff, 0, 1
						);
					}
				}
			}
		}
	}

	pub fn addLifeform(self: *Planet, lifeform: Lifeform) !void {
		self.lifeformsLock.lock();
		defer self.lifeformsLock.unlock();

		try self.lifeforms.append(self.simulationArena.allocator(), lifeform);
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
		self.simulationArena.deinit();
		
		// Mesh lifetime is managed manually by planet, for efficiency
		self.mesh.deinit(self.allocator);
		self.atmosphereMesh.deinit(self.allocator);
	}

};
