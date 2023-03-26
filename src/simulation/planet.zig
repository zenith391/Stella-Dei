const builtin = @import("builtin");
const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const zigimg = @import("zigimg");
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

const VECTOR_SIZE = std.simd.suggestVectorSize(f32) orelse 4;
const VECTOR_ALIGN = @alignOf(SimdVector);
const SimdVector = @Vector(VECTOR_SIZE, f32);
const IndexVector = @Vector(VECTOR_SIZE, usize);
const VECTOR_ZERO = @splat(VECTOR_SIZE, @as(f32, 0.0));
const VECTOR_ONE = @splat(VECTOR_SIZE, @as(f32, 1.0));

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

        var sources = [_][*c]const u8{@embedFile("../simulation/simulation.cl")};
        const program = cl.clCreateProgramWithSource(context, 1, @ptrCast([*c][*c]const u8, &sources), null, null).?;

        // TODO: use SPIR-V for the kernel?
        const buildError = cl.clBuildProgram(program, 1, &device, "-cl-strict-aliasing -cl-fast-relaxed-math", null, null);
        if (buildError != cl.CL_SUCCESS) {
            std.log.err("error building opencl program: {d}", .{buildError});

            const log = try allocator.alloc(u8, 16384);
            defer allocator.free(log);
            var size: usize = undefined;
            _ = cl.clGetProgramBuildInfo(program, device, cl.CL_PROGRAM_BUILD_LOG, log.len, log.ptr, &size);
            std.log.err("{s}", .{log[0..size]});
            return error.OpenCLError;
        }
        const temperatureKernel = cl.clCreateKernel(program, "simulateTemperature", null) orelse return error.OpenCLError;

        const temperatureBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_WRITE | cl.CL_MEM_USE_HOST_PTR, self.temperature.len * @sizeOf(f32), self.temperature.ptr, null);
        const newTemperatureBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_WRITE | cl.CL_MEM_USE_HOST_PTR, self.newTemperature.len * @sizeOf(f32), self.newTemperature.ptr, null);
        const verticesBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_ONLY | cl.CL_MEM_USE_HOST_PTR, self.vertices.len * @sizeOf(Vec3), self.vertices.ptr, null);
        const heatCapacityBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_ONLY | cl.CL_MEM_USE_HOST_PTR, self.heatCapacityCache.len * @sizeOf(f32), self.heatCapacityCache.ptr, null);
        const verticesNeighbourBuffer = cl.clCreateBuffer(context, cl.CL_MEM_READ_ONLY | cl.CL_MEM_USE_HOST_PTR, self.verticesNeighbours.len * @sizeOf([6]u32), self.verticesNeighbours.ptr, null);

        return CLContext{
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
    averageNitrogenMass: f64 = 0,
    /// The average O2 mass per point of the planet
    /// Unit: 10⁹ kg
    averageOxygenMass: f64 = 0,
    /// The average CO2 mass per point of the planet
    /// Unit: 10⁹ kg
    averageCarbonDioxideMass: f64 = 0,
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
    /// The wavelength of plant's color, in nanometers
    plantColorWavelength: f32 = 530,
    /// Buffer array that is used to store the temperatures to be used after next update
    newTemperature: []f32,
    newWaterMass: []f32,
    newWaterVaporMass: []f32,
    lifeforms: std.ArrayListUnmanaged(Lifeform),
    /// Lock used to avoid concurrent reads and writes to lifeforms arraylist
    lifeformsLock: std.Thread.Mutex = .{},
    nextMeteorite: f64 = 0,

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
            if (planet.verticesNeighbours[idx][i] == idx) {
                planet.verticesNeighbours[idx][i] = neighbor;
                return;
            } else if (planet.verticesNeighbours[idx][i] == neighbor) {
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
            const aIdx = indices[i + 0];
            const bIdx = indices[i + 1];
            const cIdx = indices[i + 2];
            appendNeighbor(planet, aIdx, bIdx);
            appendNeighbor(planet, aIdx, cIdx);
            appendNeighbor(planet, bIdx, aIdx);
            appendNeighbor(planet, bIdx, cIdx);
            appendNeighbor(planet, cIdx, aIdx);
            appendNeighbor(planet, cIdx, bIdx);
        }
    }

    const GenerationOptions = struct {
        generate_terrain: bool = true,
    };

    pub fn generate(allocator: std.mem.Allocator, numSubdivisions: usize, radius: f32, seed: u64, options: GenerationOptions) !Planet {
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
        const numPoints = mesh.num_points;
        const vertices = try simAlloc.alloc(Vec3, numPoints);
        const vertNeighbours = try simAlloc.alloc([6]u32, numPoints);
        const elevation = try simAlloc.alignedAlloc(f32, VECTOR_ALIGN, numPoints);
        const waterElev = try simAlloc.alignedAlloc(f32, VECTOR_ALIGN, numPoints);
        const airVelocity = try simAlloc.alloc(Vec2, numPoints);
        const waterVaporMass = try simAlloc.alignedAlloc(f32, VECTOR_ALIGN, numPoints);
        const rainfall = try simAlloc.alloc(f32, numPoints);
        const temperature = try simAlloc.alignedAlloc(f32, VECTOR_ALIGN, numPoints);
        const vegetation = try simAlloc.alignedAlloc(f32, VECTOR_ALIGN, numPoints);
        const newTemp = try simAlloc.alignedAlloc(f32, VECTOR_ALIGN, numPoints);
        const newWaterElev = try simAlloc.alignedAlloc(f32, VECTOR_ALIGN, numPoints);
        const newVaporMass = try simAlloc.alignedAlloc(f32, VECTOR_ALIGN, numPoints);
        const heatCapacCache = try simAlloc.alloc(f32, numPoints);

        const lifeforms = try std.ArrayListUnmanaged(Lifeform).initCapacity(simAlloc, 0);
        const bufData = try simAlloc.alloc(f32, vertices.len * 9 + 1);
        const normals = try simAlloc.alloc(Vec3, vertices.len);
        const transformedPoints = try simAlloc.alloc(Vec3, vertices.len);

        var planet = Planet{
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

        // Zero-out data
        {
            std.mem.set(f32, waterVaporMass, 0);
            std.mem.set(f32, rainfall, 0);
            std.mem.set(Vec2, airVelocity, Vec2.zero());
            std.mem.set(f32, elevation, radius);
            std.mem.set(f32, waterElev, 0);
            std.mem.set(f32, vegetation, 0);
            std.mem.set(f32, temperature, 273.15 + 22.0);

            const NITROGEN_PERCENT = 78.084 / 100.0;
            const OXYGEN_PERCENT = 20.946 / 100.0;
            const CARBON_DIOXIDE_PERCENT = 0.6 / 100.0; // estimated value from Earth prebiotic era
            const ATMOSPHERE_MASS = 5.15 * std.math.pow(f64, 10, 18 - 9);
            planet.averageNitrogenMass = @floatCast(f32, NITROGEN_PERCENT * ATMOSPHERE_MASS / @intToFloat(f64, numPoints));
            planet.averageOxygenMass = @floatCast(f32, OXYGEN_PERCENT * ATMOSPHERE_MASS / @intToFloat(f64, numPoints));
            planet.averageCarbonDioxideMass = @floatCast(f32, CARBON_DIOXIDE_PERCENT * ATMOSPHERE_MASS / @intToFloat(f64, numPoints));
        }

        if (options.generate_terrain) {
            var prng = std.rand.DefaultPrng.init(seed);
            const random = prng.random();

            const vert = mesh.vertices;
            const kmPerWaterMass = planet.getKmPerWaterMass();
            const seaLevel = radius + (random.float(f32) - 0.5) * 10; // between +5km and -5/km
            //const seaLevel: f32 = -10.0;

            std.log.info("{d} km / water ton", .{kmPerWaterMass});
            std.log.info("seed 0x{x}", .{seed});
            std.log.info("Sea Level: {d} km", .{seaLevel - radius});
            perlin.setSeed(random.int(u64));
            var i: usize = 0;
            while (i < vert.len) : (i += 3) {
                const point = Vec3.fromSlice(vert[i..]).norm();
                const value = radius + perlin.noise(point.x() * 3 + 5, point.y() * 3 + 5, point.z() * 3 + 5) * std.math.min(radius / 2, 15);

                elevation[i / 3] = value;
                waterElev[i / 3] = std.math.max(0, seaLevel - value) / kmPerWaterMass;
                vertices[i / 3] = point;
                //vegetation[i / 3] = perlin.fbm(point.x() + 5, point.y() + 5, point.z() + 5, 4) / 2 + 0.5;
                vegetation[i / 3] = 0;

                temperature[i / 3] = (1 - @fabs(point.z())) * 55 + 273.15 - 25.0;

                const totalElevation = elevation[i / 3] + waterElev[i / 3];
                const transformedPoint = point.scale(totalElevation);
                planet.transformedPoints[i / 3] = transformedPoint;
            }
        } else {
            var i: usize = 0;
            const vert = mesh.vertices;
            while (i < vert.len) : (i += 3) {
                const point = Vec3.fromSlice(vert[i..]).norm();
                vertices[i / 3] = point;
            }
        }
        zone3.End();

        // Pre-compute the neighbours of every point of the ico-sphere.
        computeNeighbours(&planet);

        for (mesh.vao) |vao| {
            gl.bindVertexArray(vao);
            // position and normal are interleaved
            gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32))); // position
            gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), @intToPtr(?*anyopaque, 3 * @sizeOf(f32))); // normal
            // temperature, water level and vegetation are sequential so we can glBufferSubData
            gl.vertexAttribPointer(2, 1, gl.FLOAT, gl.FALSE, 1 * @sizeOf(f32), @intToPtr(?*anyopaque, 6 * @sizeOf(f32) * vertices.len)); // temperature (used for a bunch of things)
            gl.vertexAttribPointer(3, 1, gl.FLOAT, gl.FALSE, 1 * @sizeOf(f32), @intToPtr(?*anyopaque, 7 * @sizeOf(f32) * vertices.len)); // water level (used in Normal display mode)
            gl.vertexAttribPointer(4, 1, gl.FLOAT, gl.FALSE, 1 * @sizeOf(f32), @intToPtr(?*anyopaque, 8 * @sizeOf(f32) * vertices.len)); // vegetation level (temporary until replaced by actual living vegetation)
            gl.enableVertexAttribArray(0);
            gl.enableVertexAttribArray(1);
            gl.enableVertexAttribArray(2);
            gl.enableVertexAttribArray(3);
            gl.enableVertexAttribArray(4);
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, mesh.vbo);
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, bufData.len * @sizeOf(f32)), bufData.ptr, gl.STREAM_DRAW);

        const meanPointArea = (4 * std.math.pi * radius * radius) / @intToFloat(f32, numPoints);
        std.log.info("There are {d} points in the ico-sphere.\n", .{numPoints});
        std.log.info("The mean area per point of the ico-sphere is {d} km²\n", .{meanPointArea});
        std.log.info("SIMD Vectors: {} x f32", .{VECTOR_SIZE});

        return planet;
    }

    pub fn loadFromImage(self: Planet, allocator: std.mem.Allocator, file: *std.fs.File) !void {
        var image = try zigimg.Image.fromFile(allocator, file);
        defer image.deinit();

        if (image.pixelFormat() != .rgba32) {
            std.log.err("Can only load images with rgba32 format!", .{});
            return error.InvalidPixelFormat;
        }

        // The process:
        // - take every point of the icosphere
        // - convert it latitude and longitude coordinates
        // - do equirectangular projection in order to convert to image coordinates
        // - use resulting value as height (TODO: do average of neighbour cells too?)

        const standardParallel: f32 = std.math.degreesToRadians(f32, 0);
        const kmPerWaterMass = self.getKmPerWaterMass();

        for (self.vertices, 0..) |*vert, idx| {
            const longitude = std.math.atan2(f32, vert.y(), vert.x());
            const latitude = std.math.acos(vert.z()) * 2;
            const imageX = @floatToInt(usize, @intToFloat(f32, image.width) / (std.math.pi * 2.0) * (longitude + std.math.pi) * std.math.cos(standardParallel));
            const imageY = std.math.min(@floatToInt(usize, @intToFloat(f32, image.height) / (std.math.pi * 2.0) * (latitude)), image.height - 1);

            const pixel = image.pixels.rgba32[imageY * image.width + imageX];
            self.elevation[idx] = self.radius + @intToFloat(f32, pixel.r) * 0.1 - 14.5;
            self.waterMass[idx] = std.math.max(0, self.radius - self.elevation[idx]) / kmPerWaterMass;
            self.vegetation[idx] = if (self.waterMass[idx] == 0.0 and self.elevation[idx] - self.radius < 5.0) 1.0 else 0.0;
        }
    }

    const HEIGHT_EXAGGERATION_FACTOR = 10;

    fn computeNormal(self: Planet, a: usize, aVec: Vec3) Vec3 {
        @setFloatMode(.Optimized);
        var sum = Vec3.zero();
        const adjacentVertices = self.getNeighbours(a);
        {
            var i: usize = 1;
            while (i < adjacentVertices.len) : (i += 1) {
                const b = adjacentVertices[i - 1];
                const bVec = self.transformedPoints[b];
                const c = adjacentVertices[i];
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
        _ = loop;
        const zone = tracy.ZoneN(@src(), "Compute normals");
        defer zone.End();

        // there could potentially be a data race between this function and upload
        // but it's not a problem as even if only a part of a normal's components are
        // updated, the glitch is barely noticeable
        for (self.transformedPoints, 0..) |point, i| {
            self.normals[i] = self.computeNormal(i, point);
        }
    }

    pub fn getKmPerWaterMass(self: Planet) f32 {
        const waterDensity = 1000.0; // kg / m³
        const meanPointArea: f64 = self.getMeanPointArea(); // m²
        const kmPerWaterMass =
            1.0 / waterDensity // m³ / kg
        / meanPointArea // m / kg
        / 1000.0 // km / kg
        * 1_000_000_000 // km / 10⁹ kg
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

            // This could be sped up by using LOD? (allowing to transfer less data)
            // NOTE: this has really bad cache locality
            const STRIDE = 6;
            for (self.vertices, 0..) |point, i| {
                const waterElevation = self.waterMass[i] * kmPerWaterMass;
                const totalElevation = self.elevation[i] + waterElevation;
                const exaggeratedElev = (totalElevation - self.radius) * HEIGHT_EXAGGERATION_FACTOR + self.radius;
                const scaledPoint = point.scale(exaggeratedElev);
                const transformedPoint = mulByVec3(rotationMatrix, scaledPoint);
                const normal = self.normals[i];
                self.transformedPoints[i] = transformedPoint;

                const bytePos = i * STRIDE;
                const bufSlice = bufData[bytePos + 0 .. bytePos + 6];
                bufSlice[0..3].* = transformedPoint.data;
                bufSlice[3..6].* = normal.data;
            }

            gl.bindBuffer(gl.ARRAY_BUFFER, self.mesh.vbo);
            gl.bufferSubData(gl.ARRAY_BUFFER, 0, @intCast(isize, 6 * @sizeOf(f32) * self.vertices.len), bufData.ptr);

            // This one is special and needs processing
            if (displayMode == .WindMagnitude) {
                for (self.airVelocity, 0..) |velocity, i| {
                    bufData[i] = velocity.x();
                }
                gl.bufferSubData(gl.ARRAY_BUFFER, 6 * @sizeOf(f32) * self.vertices.len, @intCast(isize, self.vertices.len * @sizeOf(f32)), bufData.ptr);
                for (self.airVelocity, 0..) |velocity, i| {
                    bufData[i] = velocity.y();
                }
                gl.bufferSubData(gl.ARRAY_BUFFER, 7 * @sizeOf(f32) * self.vertices.len, @intCast(isize, self.vertices.len * @sizeOf(f32)), bufData.ptr);
            } else {
                var displayedSlice = switch (displayMode) {
                    .WaterVapor => self.waterVaporMass,
                    .Rainfall => self.rainfall,
                    .Normal, .Temperature => self.temperature,
                    else => unreachable,
                };
                gl.bufferSubData(gl.ARRAY_BUFFER, 6 * @sizeOf(f32) * self.vertices.len, @intCast(isize, displayedSlice.len * @sizeOf(f32)), displayedSlice.ptr);
                gl.bufferSubData(gl.ARRAY_BUFFER, 7 * @sizeOf(f32) * self.vertices.len, @intCast(isize, self.waterMass.len * @sizeOf(f32)), self.waterMass.ptr);
            }
            gl.bufferSubData(gl.ARRAY_BUFFER, 8 * @sizeOf(f32) * self.vertices.len, @intCast(isize, self.vegetation.len * @sizeOf(f32)), self.vegetation.ptr);
        }

        {
            const STRIDE = 4;
            for (self.vertices, 0..) |point, i| {
                const transformedPoint = point.scale(self.radius + 15 * HEIGHT_EXAGGERATION_FACTOR);

                const bytePos = i * STRIDE;
                const bufSlice = bufData[bytePos + 0 .. bytePos + 4];
                bufSlice[0..3].* = transformedPoint.data;
                bufSlice[3] = self.rainfall[i];
            }

            gl.bindBuffer(gl.ARRAY_BUFFER, self.atmosphereMesh.vbo);
            gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, STRIDE * self.atmosphereMesh.num_points * @sizeOf(f32)), bufData.ptr, gl.STREAM_DRAW);
        }
    }

    pub fn render(self: *Planet, loop: *EventLoop, displayMode: DisplayMode, axialTilt: f32) void {
        self.upload(loop, displayMode, axialTilt);
        self.renderNoUpload();
    }

    pub fn renderNoUpload(self: *Planet) void {
        for (self.mesh.vao, 0..) |vao, vaoIdx| {
            gl.bindVertexArray(vao);
            gl.drawElements(gl.TRIANGLES, self.mesh.num_elements[vaoIdx], gl.UNSIGNED_INT, null);
        }
    }

    // TODO: just do it in shaders postprocess.fs
    pub fn renderClouds(self: *Planet) void {
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

    pub inline fn getNeighbourSimd(self: Planet, indexes: IndexVector, direction: Direction) IndexVector {
        const directionInt = @enumToInt(direction);
        var neighbours: IndexVector = undefined;
        // XXX: do something more parallel?
        {
            comptime var i: usize = 0;
            inline while (i < VECTOR_SIZE) : (i += 1) {
                neighbours[i] = self.verticesNeighbours[indexes[i]][directionInt];
            }
        }
        return neighbours;
    }

    pub inline fn getNeighbours(self: Planet, idx: usize) [6]usize {
        return [6]usize{
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
        for (self.transformedPoints, 0..) |point, i| {
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
        const specificHeatCapacity = exp(-waterLevel / 2_000_000) * (groundCp - waterCp) + waterCp; // J/K/kg
        // Earth is about 5513 kg/m³ (https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html) and assume each point is 0.72m thick??
        const pointMass = pointArea * 0.1 * 5513; // kg
        const heatCapacity = specificHeatCapacity * pointMass; // J.K-1
        return heatCapacity;
    }

    fn simulateTemperature(self: *Planet, loop: *EventLoop, options: SimulationOptions, start: usize, end: usize) void {
        @setFloatMode(.Optimized);
        @setRuntimeSafety(false);
        _ = loop;

        //tracy.FiberEnter("Simulate temperature");
        //defer tracy.FiberLeave();
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

        // If dt is too high, default temperature simulation will become highly inaccurate so
        // we switch to an average simulation.
        const simulatePrecisely = dt < options.planetRotationTime / 4;

        // In W.m-1.K-1, this is 1 assuming 100% of planet is SiO2 :/
        const thermalConductivityMultiplier = 10.0; // real world thermal conductivity is too low for a game
        const groundThermalConductivity: f32 = 1 * thermalConductivityMultiplier;
        const waterThermalConductivity: f32 = 0.6089 * thermalConductivityMultiplier;

        if (simulatePrecisely) {
            var i: usize = start;
            // NEW(TM) heat simulation
            while (i < end) : (i += 1) {
                const normVert = self.transformedPoints[i].norm();
                // Temperature in the current cell
                const temp = self.temperature[i];

                const waterLevel = self.waterMass[i];
                const thermalConductivity = exp(-waterLevel / 2) * (groundThermalConductivity - waterThermalConductivity) + waterThermalConductivity; // W.m-1.K-1
                const heatCapacity = heatCapacityCache[i];

                var totalTemperatureGain: f32 = 0;

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
                    // TODO: albedo, ice has a higher albedo than liquid water

                    totalTemperatureGain += temperatureGain;
                }

                // Thermal radiation with Stefan-Boltzmann law
                {
                    const stefanBoltzmannConstant = 0.00000005670374; // W.m-2.K-4
                    // water emissivity: 0.96
                    // limestone emissivity: 0.92
                    const emissivity = 0.93; // took a value between the two
                    const radiantEmittance = stefanBoltzmannConstant * temp * temp * temp * temp * emissivity; // W.m-2
                    const h2o = self.waterVaporMass[i] / meanPointArea;
                    const co2 = self.averageCarbonDioxideMass / meanPointArea;
                    // IRL, H2O and CO2 are the two major greenhouse gases
                    // This is a very crude approximation of the greenhouse effect
                    const greenhouseEffect = @min(radiantEmittance * 0.9, @floatCast(f32, (h2o * 4 + co2 * 40) * std.math.ln(radiantEmittance) * 64000));
                    const heatTransfer = (radiantEmittance - greenhouseEffect) * meanPointAreaTime; // J
                    const temperatureLoss = heatTransfer / heatCapacity; // K
                    totalTemperatureGain -= temperatureLoss;
                }
                newTemp[i] += totalTemperatureGain;
            }
        } else {
            var i: usize = start;
            // NEW(TM) heat simulation
            while (i < end) : (i += 1) {
                const normVert = self.transformedPoints[i].norm();
                // Temperature in the current cell
                const temp = self.temperature[i];
                const heatCapacity = heatCapacityCache[i];

                var totalTemperatureGain: f32 = 0;

                // TODO: solve the temperature by calculating with differential
                // for 4 times planetRotationTime / 4 steps
                // (thus with the solarVector at predefined cardinal positions)
                // that would be more accurate and have less bugs than current approach

                // Solar irradiance
                {
                    // Divide by 2 because it should only be lit 1/2th of the time
                    // technically we should divide more to take into account morning and evening not having max solarCoeff
                    // but whatever
                    const solarCoeff = (1 - @fabs(normVert.z()));
                    // TODO: Direct Normal Irradiance? when we have atmosphere
                    //const solarIrradiance = options.solarConstant * solarCoeff * meanPointArea; // W = J.s-1
                    // So, we get heat transfer in J
                    //const heatTransfer = solarIrradiance * dt;
                    const heatTransfer = options.solarConstant * solarCoeff * meanPointAreaTime;
                    const temperatureGain = heatTransfer / heatCapacity; // K
                    // TODO: albedo, ice has a higher albedo than liquid water

                    totalTemperatureGain += temperatureGain;
                }

                // Thermal radiation with Stefan-Boltzmann law
                {
                    const stefanBoltzmannConstant = 0.00000005670374; // W.m-2.K-4
                    // water emissivity: 0.96
                    // limestone emissivity: 0.92
                    const emissivity = 0.93; // took a value between the two
                    const radiantEmittance = stefanBoltzmannConstant * temp * temp * temp * temp * emissivity; // W.m-2
                    const h2o = self.waterVaporMass[i] / meanPointArea;
                    const co2 = self.averageCarbonDioxideMass / meanPointArea;
                    // IRL, H2O and CO2 are the two major greenhouse gases
                    // This is a very crude approximation of the greenhouse effect
                    const greenhouseEffect = @min(radiantEmittance * 0.9, @floatCast(f32, (h2o * 4 + co2 * 40) * std.math.ln(radiantEmittance) * 64000));
                    const heatTransfer = (radiantEmittance - greenhouseEffect) * meanPointAreaTime; // J
                    const temperatureLoss = heatTransfer / (heatCapacity / 1.75); // K
                    totalTemperatureGain -= temperatureLoss;
                }
                newTemp[i] += totalTemperatureGain;
            }
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
        const kernelError = cl.clEnqueueNDRangeKernel(ctx.queue, ctx.simulationKernel, 1, null, &global_work_size, null, 0, null, null);
        if (kernelError != cl.CL_SUCCESS) {
            std.log.err("Error running kernel: {d}", .{kernelError});
            std.os.exit(1);
        }
        _ = cl.clFinish(ctx.queue);
    }

    inline fn loadSimdVector(slice: []const f32, i: usize) *const SimdVector {
        return @ptrCast(*const SimdVector, @alignCast(VECTOR_ALIGN, &slice[i]));
    }

    inline fn saveSimdVector(slice: []f32, i: usize, vector: SimdVector) void {
        @ptrCast(*SimdVector, @alignCast(VECTOR_ALIGN, &slice[i])).* = vector;
    }

    fn simulateWater(self: *Planet, loop: *EventLoop, options: SimulationOptions, numIterations: usize, start: usize, end: usize) void {
        _ = loop;
        const zone = tracy.ZoneN(@src(), "Water Simulation");
        defer zone.End();

        const dt = options.dt * options.timeScale;

        const meanPointArea = self.getMeanPointArea();
        const meanDistance = std.math.sqrt(meanPointArea); // m
        const meanDistanceKm = meanDistance / 1000; // km
        const kmPerWaterMass = self.getKmPerWaterMass(); // km / 10⁹ kg

        const shareFactor = std.math.min(0.00002 * dt / (6 * @intToFloat(f32, numIterations)), 1.0 / 7.0);
        const substanceDivider: f64 = self.getSubstanceDivider();
        const meanAtmVolume: f64 = self.getMeanPointArea() * 12_000; // m³

        const evaporationAmt = @as(f32, 0.1) * meanPointArea * dt;

        // Do some liquid simulation
        const counting_vector = std.simd.iota(usize, VECTOR_SIZE);
        var i: usize = start;
        if (dt < 86400 / 4) {
            while (i < end - VECTOR_SIZE + 1) : (i += VECTOR_SIZE) {
                // only fluid if it's not ice
                const indices = @splat(VECTOR_SIZE, i) + counting_vector; // i + 0, i + 1, i + 2, ...
                const temp = loadSimdVector(self.temperature, i).*;
                const elevation = loadSimdVector(self.elevation, i).*;
                var mass = loadSimdVector(self.newWaterMass, i).*;
                const vaporMass = loadSimdVector(self.newWaterVaporMass, i).*;

                {
                    const doBoiling = temp > @splat(VECTOR_SIZE, @as(f32, 373.15));
                    const diff = @min(mass, @splat(VECTOR_SIZE, evaporationAmt));
                    mass -= @select(f32, doBoiling, diff, VECTOR_ZERO);
                }

                // Mass to remove from the current cell because it has been shared to others or evaporated
                {
                    const RH = Planet.getRelativeHumidities(substanceDivider, temp, vaporMass);
                    // evaporation only happens when the air isn't saturated and when the water is above 0°C
                    const hasSuitableHumidity = RH < @splat(VECTOR_SIZE, @as(f32, 1.0));
                    const isLiquid = temp > @splat(VECTOR_SIZE, @as(f32, 273.15));
                    const doEvaporation = @select(bool, hasSuitableHumidity, isLiquid, @splat(VECTOR_SIZE, false));
                    const computedDiff = @min(@splat(VECTOR_SIZE, 10 * dt), mass);
                    const diff = @select(f32, doEvaporation, computedDiff, VECTOR_ZERO);
                    mass -= diff;
                    saveSimdVector(self.newWaterVaporMass, i, vaporMass + diff);
                }

                // TODO: ebulittion

                const totalHeight = elevation + mass * @splat(VECTOR_SIZE, kmPerWaterMass);
                const shared = mass * @splat(VECTOR_SIZE, shareFactor);

                var massToRemove = @splat(VECTOR_SIZE, @as(f32, 0.0));
                //_ = shared; _ = totalHeight; _ = indices;
                massToRemove += self.sendWater(self.getNeighbourSimd(indices, .ForwardLeft), indices, shared, totalHeight, kmPerWaterMass);
                massToRemove += self.sendWater(self.getNeighbourSimd(indices, .ForwardRight), indices, shared, totalHeight, kmPerWaterMass);
                massToRemove += self.sendWater(self.getNeighbourSimd(indices, .BackwardLeft), indices, shared, totalHeight, kmPerWaterMass);
                massToRemove += self.sendWater(self.getNeighbourSimd(indices, .BackwardRight), indices, shared, totalHeight, kmPerWaterMass);
                massToRemove += self.sendWater(self.getNeighbourSimd(indices, .Left), indices, shared, totalHeight, kmPerWaterMass);
                massToRemove += self.sendWater(self.getNeighbourSimd(indices, .Right), indices, shared, totalHeight, kmPerWaterMass);

                std.debug.assert(@reduce(.And, (mass - massToRemove) >= VECTOR_ZERO));
                saveSimdVector(self.newWaterMass, i, mass - massToRemove);
            }
        }

        // Those are simply the coordinates of points in an hexagon,
        // which is enough to get a (rough approximation of a) tangent
        // vector.
        const tangentVectors = [6]Vec2{
            Vec2.new(-0.5, 0.9),
            Vec2.new(-0.5, -0.9),
            Vec2.new(-1.0, 0.0),
            Vec2.new(0.5, 0.9),
            Vec2.new(0.5, -0.9),
            Vec2.new(1.0, 0.0),
        };

        // Do some water vapor simulation
        i = start;
        while (i < end) : (i += 1) {
            const mass = self.newWaterVaporMass[i];
            const T = self.temperature[i]; // TODO: separate air temperature?
            const pressure = self.getAirPressure(substanceDivider, T, mass);
            self.rainfall[i] = std.math.max(0, self.rainfall[i] * (1.0 - dt / 86400.0));

            if (false) {
                for (self.getNeighbours(i), 0..) |neighbourIdx, location| {
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
                        //const diff = mass;
                        self.newWaterMass[i] += diff;
                        self.newWaterVaporMass[i] -= diff;
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
                    velocity = velocity.add(Vec2.new(spinRate * 2.0 * @sin(latitude) * dt, 0));
                }

                // Apply drag
                {
                    const velocityN = velocity.length() * 10; // * 10 given the square after, so that the result is in km/s while still being the same as if velocity was expressed in m/s in the computation
                    const dragCoeff = 1.55;
                    const area = meanPointArea / 1000 * (@max(0.1, (self.elevation[i] - self.radius) / 10)); // TODO: depend on steepness!!

                    // It's supposed to be * kg/m³ but as we divide by kg later, it's faster to directly divide by m³
                    const dragForce = 1.0 / 2.0 * velocityN * velocityN * dragCoeff * area / meanPointArea; // * massDensity // TODO: depend on Mach number?
                    velocity = velocity.sub(velocity.norm().scale(std.math.clamp(dragForce * dt, 0, velocityN / 20)));
                }

                var appliedVelocity = Vec3.new(velocity.x() * dt, velocity.y() * dt, 0);
                if (appliedVelocity.dot(appliedVelocity) > meanDistanceKm * meanDistanceKm) { // length squared > meanDistanceKm²
                    appliedVelocity = appliedVelocity.norm().scale(meanDistanceKm);
                }

                // Vector corresponding to the right-center point of the tangent plane of the sphere passing through current point
                const right = transformedPoint.cross(Vec3.back()).norm();

                // Vector corresponding to the center-up point on the tangent plane
                const up = transformedPoint.cross(right).norm();
                const targetPos = transformedPoint.add(right.scale(appliedVelocity.x()).add(up.scale(appliedVelocity.y())));

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

    pub inline fn getPartialPressures(substanceDivider: f64, temperatures: SimdVector, masses: SimdVector) @Vector(VECTOR_SIZE, f64) {
        // Intermediary computations are done if f64
        const k = @splat(VECTOR_SIZE, 1.380649 * comptime std.math.pow(f64, 10, -23)); // Boltzmann constant

        // Workaround as you can't do @floatCast with a vector
        // TODO: send issue to ziglang/zig
        // TODO: benchmark whether manually @floatCast'ing makes it slower than a naive non-SIMD approach
        const masses_f64 = blk: {
            var vector: @Vector(VECTOR_SIZE, f64) = undefined;
            comptime var i: usize = 0;
            inline while (i < VECTOR_SIZE) : (i += 1) {
                vector[i] = @floatCast(f64, masses[i]);
            }
            break :blk vector;
        };

        const temperatures_f64 = blk: {
            var vector: @Vector(VECTOR_SIZE, f64) = undefined;
            comptime var i: usize = 0;
            inline while (i < VECTOR_SIZE) : (i += 1) {
                vector[i] = @floatCast(f64, temperatures[i]);
            }
            break :blk vector;
        };

        const waterPartialPressures = (masses_f64 * k * temperatures_f64) / @splat(VECTOR_SIZE, substanceDivider); // Pa
        return waterPartialPressures;
    }

    /// Returns the mass of all the air above the given point's area, in 10⁹ kg
    pub inline fn getAirMass(self: Planet, idx: usize) f32 {
        // + 1 is because there will never be 0 kg of air (and if it's the case it breaks a bunch of computations)
        return self.waterVaporMass[idx] + self.averageNitrogenMass + self.averageOxygenMass + self.averageCarbonDioxideMass + 1;
    }

    pub inline fn getAirPressure(self: Planet, substanceDivider: f64, temperature: f32, vaporMass: f64) f32 {
        return @floatCast(f32, getPartialPressure(substanceDivider, temperature, vaporMass + self.averageNitrogenMass + self.averageOxygenMass + self.averageCarbonDioxideMass + 1));
    }

    /// Returns the pressure that air excerts on a given point, in Pascal.
    pub fn getAirPressureOfPoint(self: Planet, idx: usize) f32 {
        return self.getAirPressure(self.getSubstanceDivider(), self.temperature[idx], self.waterVaporMass[idx]);
    }

    /// Uses Tetens equation
    /// The fact that it is off for below 0°C isn't important as we're doing
    /// quite big approximations anyways
    fn getEquilibriumVaporPressure_Unoptimized(temperature: f32) f32 {
        return 0.61078 * @exp(17.27 * (temperature - 273.15) / (temperature + 237.3 - 273.15)) * 1000;
    }

    /// We precompute the values from getEquilibriumVaporPressure so that calling the function
    /// is faster.
    const equilibriumVaporPressures = blk: {
        const from = 0.0;
        const to = 1000.0;
        const step = 1.0;
        const arrayLength = @floatToInt(usize, (to - from) / step);
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
        if (temperature >= 999 or temperature <= 0 or std.math.isNan(temperature)) {
            // This shouldn't be possible with default ranges, so no need to optimize
            return getEquilibriumVaporPressure_Unoptimized(temperature);
        } else {
            const idx = @floatToInt(u32, temperature);
            return lerp(equilibriumVaporPressures[idx], equilibriumVaporPressures[idx + 1], @rem(temperature, 1));
        }
    }

    /// This function is implemented quite naively as indexing isn't easily parallelizable
    pub inline fn getEquilibriumVaporPressures(temperature: SimdVector) @Vector(VECTOR_SIZE, f64) {
        var vector: @Vector(VECTOR_SIZE, f64) = undefined;
        comptime var i: usize = 0;
        inline while (i < VECTOR_SIZE) : (i += 1) {
            vector[i] = getEquilibriumVaporPressure(temperature[i]);
        }
        return vector;
    }

    pub inline fn getRelativeHumidity(substanceDivider: f64, temperature: f32, mass: f64) f32 {
        return @floatCast(f32, getPartialPressure(substanceDivider, temperature, mass) / getEquilibriumVaporPressure(temperature));
    }

    pub inline fn getRelativeHumidities(substanceDivider: f64, temperatures: SimdVector, masses: SimdVector) SimdVector {
        const results = getPartialPressures(substanceDivider, temperatures, masses) / getEquilibriumVaporPressures(temperatures);
        const results_f32 = blk: {
            var vector: @Vector(VECTOR_SIZE, f32) = undefined;
            comptime var i: usize = 0;
            inline while (i < VECTOR_SIZE) : (i += 1) {
                vector[i] = @floatCast(f32, results[i]);
            }
            break :blk vector;
        };
        return results_f32;
    }

    /// Returns the constant used for computations with the perfect gas law
    pub fn getSubstanceDivider(self: Planet) f64 {
        // The mean atmosphere volume per point is approximately equal
        // to mean point area multiplied by the height of the troposphere (~12km)
        const meanAtmVolume: f64 = self.getMeanPointArea() * 12_000; // m³

        const NA = 6.02214076 * std.math.pow(f64, 10, 23); // NA = 6.02214076 × 10²³
        // Atmospheric volume accounted for amount of substance and 10¹² g units
        const substanceDivider: f64 = meanAtmVolume * 18.015 // there are 18.015g in a mole of water
        / std.math.pow(f64, 10, 12) // water mass is in 10⁹ kg (= 10¹² g)
        / NA; // account for Avogadro constant
        return substanceDivider;
    }

    fn sendWater(self: Planet, target: IndexVector, origin: IndexVector, shared: SimdVector, totalHeight: SimdVector, kmPerWaterMass: f32) SimdVector {
        const elevation = blk: {
            var vector: SimdVector = undefined;
            comptime var i: usize = 0;
            inline while (i < VECTOR_SIZE) : (i += 1) {
                vector[i] = self.elevation[target[i]];
            }
            break :blk vector;
        };
        const waterMass = blk: {
            var vector: SimdVector = undefined;
            comptime var i: usize = 0;
            inline while (i < VECTOR_SIZE) : (i += 1) {
                vector[i] = self.waterMass[target[i]];
            }
            break :blk vector;
        };
        const targetTotalHeight = elevation + waterMass * @splat(VECTOR_SIZE, kmPerWaterMass);

        const doTransmit = totalHeight > targetTotalHeight;
        const originalTransmitted = @min(shared, shared * (totalHeight - targetTotalHeight) / @splat(VECTOR_SIZE, kmPerWaterMass) / @splat(VECTOR_SIZE, @as(f32, 2.0)));

        const zero = @splat(VECTOR_SIZE, @as(f32, 0.0));
        var transmitted = @select(f32, doTransmit, originalTransmitted, zero);

        // Do not transfer to a point that is loaded in the current vector
        // This causes water to disappear
        for (@as([VECTOR_SIZE]usize, target), 0..) |target_elem, idx| {
            if (@reduce(.Or, origin == @splat(VECTOR_SIZE, target_elem))) {
                transmitted[idx] = 0;
            }
        }

        {
            comptime var i: usize = 0;
            inline while (i < VECTOR_SIZE) : (i += 1) {
                self.newWaterMass[target[i]] += transmitted[i];
            }
        }
        return transmitted;
    }

    // fn sendWater(self: Planet, target: usize, shared: f32, totalHeight: f32, kmPerWaterMass: f32) f32 {
    // 	const targetTotalHeight = self.elevation[target] + self.waterMass[target] * kmPerWaterMass;
    // 	if (totalHeight > targetTotalHeight) {
    // 		var transmitted = std.math.min(shared, shared * (totalHeight - targetTotalHeight) / 2 / kmPerWaterMass);
    // 		std.debug.assert(transmitted >= 0);
    // 		self.newWaterMass[target] += transmitted;
    // 		return transmitted;
    // 	} else {
    // 		return 0;
    // 	}
    // }

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

    fn simulateVegetation(self: *Planet, options: SimulationOptions, start: usize, end: usize) void {
        const zone = tracy.ZoneN(@src(), "Vegetation Simulation");
        defer zone.End();

        const dt = options.dt * options.timeScale;
        // The surface of the planet (approx.) divided by the numbers of points
        const meanPointArea = self.getMeanPointArea(); // m²
        const solarVector = options.solarVector;

        // Normally, I should take the distance from the planet to the star and calculate thingies but no
        const solarIrrCoeff = options.solarConstant * meanPointArea * @intToFloat(f32, self.vegetation.len); // W
        const stefanBoltzmannConstant = 0.00000005670374; // W.m-2.K-4
        const wienConstant = 0.002897729; // K.m
        const solarTemperature = std.math.pow(f32, solarIrrCoeff / stefanBoltzmannConstant, 1.0 / 8.0) * 4;
        const maxWavelength = wienConstant / solarTemperature;
        const m_to_nm = std.math.pow(f32, 10.0, 9.0);
        self.plantColorWavelength = maxWavelength * m_to_nm;

        // TODO: multiple species

        var i = start;
        while (i < end) : (i += 1) {
            const vert = self.transformedPoints[i];
            const normVert = vert.norm();
            const solarCoeff = std.math.max(0, normVert.dot(solarVector) / normVert.length());
            var newVegetation = self.vegetation[i];
            // TODO: Direct Normal Irradiance? when we have atmosphere

            _ = solarCoeff;
            newVegetation -= 0.0001 * dt * @as(f32, if (self.waterMass[i] >= 1_000_000) 1.0 else 0.0);

            for (self.getNeighbours(i)) |neighbourIndex| {
                if (self.vegetation[neighbourIndex] < newVegetation) {
                    self.vegetation[neighbourIndex] += 0.000001 * dt * newVegetation;
                }
            }
            newVegetation = std.math.clamp(newVegetation, 0, 1);

            // TODO: only when it's sunny
            const gasMass = newVegetation * dt * 100 / meanPointArea;
            const enoughCO2 = @intToFloat(f32, @boolToInt(self.averageCarbonDioxideMass > gasMass));
            self.averageCarbonDioxideMass -= gasMass * enoughCO2;
            self.averageOxygenMass += gasMass * enoughCO2;

            newVegetation -= (1 - enoughCO2) * dt * 0.00001;
            newVegetation = std.math.clamp(newVegetation, 0, 1);
            self.vegetation[i] = newVegetation;
        }
    }

    pub fn simulate(self: *Planet, loop: *EventLoop, options: SimulationOptions) void {
        //const zone = tracy.ZoneN(@src(), "Simulate planet");
        //defer zone.End();

        const newTemp = self.newTemperature;
        // Fill newTemp with the current temperatures
        // NOTE: we can copy using memcpy if another way to avoid negative values is found
        for (self.vertices, 0..) |_, i| {
            newTemp[i] = std.math.max(0, self.temperature[i]); // temperature may never go below 0°K
        }

        // TODO: mix both
        if (USE_OPENCL and self.clContext != null) {
            const clContext = self.clContext.?;
            self.simulateTemperature_OpenCL(clContext, options, 0, self.temperature.len);
            std.log.info("new temp at 0: {d}", .{self.newTemperature[0]});
        } else {
            // TODO: allocate jobs using FixedBufferAllocator for performance
            var jobs: [32]*Job(void) = undefined;
            const parallelness = std.math.min(loop.getParallelCount(), jobs.len);
            const pointCount = self.vertices.len;
            var i: usize = 0;
            while (i < parallelness) : (i += 1) {
                const start = pointCount / parallelness * i;
                const end = if (i == parallelness - 1) pointCount else pointCount / parallelness * (i + 1);
                const job = Job(void).create(loop) catch unreachable;
                job.call(simulateTemperature, .{ self, loop, options, start, end }) catch unreachable;
                jobs[i] = job;
            }

            i = 0;
            while (i < parallelness) : (i += 1) {
                jobs[i].wait();
            }
        }

        // Finish by swapping the new temperature
        std.mem.swap([]f32, &self.temperature, &self.newTemperature);

        const dt = options.dt * options.timeScale;
        // Disable water simulation when timescale is above 100 000
        if (dt < 15000 or true) {
            var iteration: usize = 0;
            var numIterations: usize = 1;
            while (iteration < numIterations) : (iteration += 1) {
                std.mem.copy(f32, self.newWaterMass, self.waterMass);
                std.mem.copy(f32, self.newWaterVaporMass, self.waterVaporMass);

                {
                    var jobs: [32]*Job(void) = undefined;
                    const parallelness = std.math.min(loop.getParallelCount(), jobs.len);
                    const pointCount = self.vertices.len;
                    var i: usize = 0;
                    while (i < parallelness) : (i += 1) {
                        const start = pointCount / parallelness * i;
                        const end = if (i == parallelness - 1) pointCount else pointCount / parallelness * (i + 1);
                        const job = Job(void).create(loop) catch unreachable;
                        job.call(simulateWater, .{ self, loop, options, numIterations, start, end }) catch unreachable;
                        jobs[i] = job;
                    }

                    i = 0;
                    while (i < parallelness) : (i += 1) {
                        jobs[i].wait();
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
        if (dt > 365 * std.time.ns_per_day) {}

        if (options.gameTime > self.nextMeteorite and false) {
            var prng = std.rand.DefaultPrng.init(@floatToInt(u64, options.gameTime));
            const random = prng.random();
            const impactCenter = random.intRangeLessThanBiased(usize, 0, self.vertices.len);
            std.log.info("METEORITE AT {d}", .{impactCenter});

            // TODO: use the random composition of meteorite
            const waterComposition = 1; // 100%
            const meteoriteMass = 0; // TODO
            _ = waterComposition;
            _ = meteoriteMass;

            // TODO: increase average gas
            // TODO: the meteorite has a chance of not reaching ground if atmosphere is thick enough
            // TODO: technically this just depends on the time era, meteorites hit Earth when it was early in its formation only

            // Spread the impact on multiple points near the impact center
            var hitPoints = std.BoundedArray(usize, 7).init(0) catch unreachable;
            hitPoints.append(impactCenter) catch unreachable;
            for (hitPoints.constSlice()) |point| {
                for (self.getNeighbours(point)) |neighbour| {
                    hitPoints.append(neighbour) catch unreachable;
                }
            }

            // Make the impact on the selected points
            for (hitPoints.constSlice()) |point| {
                self.waterMass[point] += 5 / self.getKmPerWaterMass();
                self.temperature[point] = 473.15;
            }
            self.nextMeteorite = options.gameTime + 1 * 8640 + 5 * random.float(f64) * 8640;
        }

        if (options.timeScale < 100000) {
            const zone = tracy.ZoneN(@src(), "Life Simulation");
            defer zone.End();

            self.lifeformsLock.lock();
            defer self.lifeformsLock.unlock();
            for (self.lifeforms.items, 0..) |*lifeform, i| {
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

        if (options.timeScale < 100000 or true) {
            // TODO: better
            {
                var jobs: [32]*Job(void) = undefined;
                const parallelness = std.math.min(loop.getParallelCount(), jobs.len);
                const pointCount = self.vertices.len;
                var i: usize = 0;
                while (i < parallelness) : (i += 1) {
                    const start = pointCount / parallelness * i;
                    const end = if (i == parallelness - 1) pointCount else pointCount / parallelness * (i + 1);
                    const job = Job(void).create(loop) catch unreachable;
                    job.call(simulateVegetation, .{ self, options, start, end }) catch unreachable;
                    jobs[i] = job;
                }

                i = 0;
                while (i < parallelness) : (i += 1) {
                    jobs[i].wait();
                }
            }

            //var i: usize = 0;
            //while (i < self.vertices.len) : (i += 1) {
            //    const vegetation = self.vegetation[i];
            //    const waterMass = self.waterMass[i];
            //    var newVegetation: f32 = vegetation;
            //    // vegetation roots can drown in too much water
            //    newVegetation -= 0.0001 * dt * @as(f32, if (self.waterMass[i] >= 1_000_000) 1.0 else 0.0);
            //    newVegetation -= 0.0001 * dt * @as(f32, if (self.elevation[i] - self.radius >= 7) 1.0 else 0.0);
            //    // but it still needs water to grow
            //    const shareCoeff = @as(f32, if (waterMass >= 10) 1.0 else 0.0);
            //    newVegetation -= 0.0000001 * dt / 10;
            //    // TODO: actually consume the water ?

            //    const isInappropriateTemperature = self.temperature[i] >= 273.15 + 50.0 or self.temperature[i] <= 273.15 - 5.0;
            //    newVegetation -= 0.000001 * dt * @as(f32, if (isInappropriateTemperature) 1.0 else 0.0);
            //    self.vegetation[i] = std.math.max(0, newVegetation);

            //    for (self.getNeighbours(i)) |neighbour| {
            //        if (self.waterMass[neighbour] < 0.1) {
            //            self.vegetation[neighbour] = std.math.clamp(self.vegetation[neighbour] + vegetation * 0.0000001 * dt * shareCoeff, 0, 1);
            //        }
            //    }
            //}
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
