const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const nk = @import("../nuklear.zig");

const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const Texture = @import("../renderer.zig").Texture;
const MouseButton = @import("glfw").mouse_button.MouseButton;
const SoundTrack = @import("../audio.zig").SoundTrack;

const Lifeform = @import("../simulation/life.zig").Lifeform;
const Planet = @import("../simulation/planet.zig").Planet;

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

pub const CubeMesh = struct {
	const vertices = [36*3]f32 {
		-0.5, -0.5, -0.5,
		 0.5, -0.5, -0.5,
		 0.5,  0.5, -0.5,
		 0.5,  0.5, -0.5,
		-0.5,  0.5, -0.5,
		-0.5, -0.5, -0.5,

		-0.5, -0.5,  0.5,
		 0.5, -0.5,  0.5,
		 0.5,  0.5,  0.5,
		 0.5,  0.5,  0.5,
		-0.5,  0.5,  0.5,
		-0.5, -0.5,  0.5,

		-0.5,  0.5,  0.5,
		-0.5,  0.5, -0.5,
		-0.5, -0.5, -0.5,
		-0.5, -0.5, -0.5,
		-0.5, -0.5,  0.5,
		-0.5,  0.5,  0.5,

		 0.5,  0.5,  0.5,
		 0.5,  0.5, -0.5,
		 0.5, -0.5, -0.5,
		 0.5, -0.5, -0.5,
		 0.5, -0.5,  0.5,
		 0.5,  0.5,  0.5,

		-0.5, -0.5, -0.5,
		 0.5, -0.5, -0.5,
		 0.5, -0.5,  0.5,
		 0.5, -0.5,  0.5,
		-0.5, -0.5,  0.5,
		-0.5, -0.5, -0.5,

		-0.5,  0.5, -0.5,
		 0.5,  0.5, -0.5,
		 0.5,  0.5,  0.5,
		 0.5,  0.5,  0.5,
		-0.5,  0.5,  0.5,
		-0.5,  0.5, -0.5,
	};

	var cube_vao: ?gl.GLuint = null;

	pub fn getVAO() gl.GLuint {
		if (cube_vao == null) {
			var vao: gl.GLuint = undefined;
			gl.genVertexArrays(1, &vao);
			var vbo: gl.GLuint = undefined;
			gl.genBuffers(1, &vbo);

			gl.bindVertexArray(vao);
			gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
			gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, vertices.len * @sizeOf(f32)), &vertices, gl.STATIC_DRAW);
			gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32))); // position
			gl.enableVertexAttribArray(0);
			cube_vao = vao;
		}
		return cube_vao.?;
	}
};

pub const SunMesh = struct {
	const IcosphereMesh = @import("../utils.zig").IcosphereMesh;

	var sun_mesh: ?IcosphereMesh = null;

	pub fn getMesh(allocator: std.mem.Allocator) IcosphereMesh {
		if (sun_mesh == null) {
			const mesh = IcosphereMesh.generate(allocator, 3) catch unreachable;
			gl.bindVertexArray(mesh.vao);
			gl.bindBuffer(gl.ARRAY_BUFFER, mesh.vbo);
			gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32))); // position
			gl.enableVertexAttribArray(0);
			gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, mesh.vertices.len * @sizeOf(f32)), mesh.vertices.ptr, gl.STREAM_DRAW);
			sun_mesh = mesh;
		}
		return sun_mesh.?;
	}
};

const GameTool = enum {
	None,
	/// When enabled, emits water at selected point on click
	EmitWater,
	/// When enabled, set vegetation level to 1 at selected point on click
	DrainWater,
	/// When enabled, drains all water near selected point on click
	PlaceVegetation,
	/// When enabled, place lifeform on click
	PlaceLife,
	RaiseTerrain,
	LowerTerrain
};

pub const PlayState = struct {
	/// The previous mouse position that was recorded during dragging (to move the camera).
	dragStart: Vec2,
	planet: Planet,
	/// Noise cubemap used for rendering terrains with a terrain quality that
	/// seems higher than it is really.
	noiseCubemap: Texture,
	skyboxCubemap: Texture,

	/// The position of the camera
	/// This is already scaled by cameraDistance
	cameraPos: Vec3 = Vec3.new(0, -8000, 2000),
	/// The target camera position, every frame, a linear interpolation is done
	/// between the current camera position and the target position, to create a
	/// smooth moving effect.
	targetCameraPos: Vec3 = Vec3.new(0, -8, 2),
	/// The distance the camera is from the planet's center
	cameraDistance: f32,
	targetCameraDistance: f32,
	/// The index of the currently selected point
	selectedPoint: usize = 0,
	displayMode: Planet.DisplayMode = .Normal,
	/// Inclination of rotation, in degrees
	axialTilt: f32 = 23.4,
	/// The solar constant in W.m-2
	solarConstant: f32 = 1361,
	/// The time it takes for the planet to do a full rotation on itself, in seconds
	planetRotationTime: f32 = 86400,
	/// The time elapsed in seconds since the start of the game
	gameTime: f64 = 0,
	/// Time scale for the simulation.
	/// This is the number of in-game seconds that passes for each real second
	timeScale: f32 = 20000,
	/// Whether the game is paused, this has the same effect as setting timeScale to
	/// 0 except it preserves the time scale value.
	paused: bool = false,
	showPlanetControl: bool = false,

	debug_clearWater: bool = false,
	debug_deluge: bool = false,
	/// Save the game on the next call to update()
	defer_saveGame: bool = false,

	selectedTool: GameTool = .None,
	meanTemperature: f32 = 0.0,

	pub fn init(game: *Game) PlayState {
		const soundTrack = SoundTrack { .items = &.{
			"assets/music1.mp3",
			"assets/music2.mp3"
		}};
		game.audio.playSoundTrack(soundTrack);

		// Create the noise cubemap for terrain detail
		const cubemap = Texture.initCubemap();
		var data: []u8 = game.allocator.alloc(u8, 512 * 512 * 3) catch unreachable;
		defer game.allocator.free(data);

		// The seed is constant as it should not be changed between plays for consistency
		var prng = std.rand.DefaultPrng.init(1234);
		var randomPrng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.milliTimestamp()));

		// Generate white noise (using the PRNG) to fill all of the cubemap's faces
		const faces = [_]Texture.CubemapFace { .PositiveX, .NegativeX, .PositiveY, .NegativeY, .PositiveZ, .NegativeZ };
		for (faces) |face| {
			var y: usize = 0;
			while (y < 512) : (y += 1) {
				var x: usize = 0;
				while (x < 512) : (x += 1) {
					// Currently, cubemap faces are in RGB format so only the red channel
					// is filled. (TODO: switch to GRAY8 format)
					data[(y*512+x)*3+0] = prng.random().int(u8);
				}
			}
			cubemap.setCubemapFace(face, 512, 512, data);
		}

		// Create the skybox
		const skybox = Texture.initCubemap();
		for (faces) |face| {
			skybox.loadCubemapFace(game.allocator, face, "assets/starsky-1024.png") catch {};
		}

		// TODO: make a loading scene
		const planetRadius = 5000; // a radius a bit smaller than Earth's (~6371km)
		const seed = randomPrng.random().int(u64);
		const planet = Planet.generate(game.allocator, 6, planetRadius, seed) catch unreachable;

		const cursorPos = game.window.getCursorPos() catch unreachable;
		return PlayState {
			.dragStart = Vec2.new(@floatCast(f32, cursorPos.xpos), @floatCast(f32, cursorPos.ypos)),
			.noiseCubemap = cubemap,
			.skyboxCubemap = skybox,
			.planet = planet,
			.cameraDistance = planetRadius * 10,
			.targetCameraDistance = planetRadius * 2.5,
		};
	}

	pub fn render(self: *PlayState, game: *Game, renderer: *Renderer) void {
		const window = renderer.window;
		const size = renderer.framebufferSize;

		// Move the camera when dragging the mouse
		if (window.getMouseButton(.right) == .press) {
			const glfwCursorPos = game.window.getCursorPos() catch unreachable;
			const cursorPos = Vec2.new(@floatCast(f32, glfwCursorPos.xpos), @floatCast(f32, glfwCursorPos.ypos));
			const delta = cursorPos.sub(self.dragStart).scale(1 / 100.0);
			const right = self.targetCameraPos.cross(Vec3.forward()).norm();
			const backward = self.targetCameraPos.cross(right).norm();
			self.targetCameraPos = self.targetCameraPos
				.add(right.scale(delta.x())
				.add(backward.scale(-delta.y()))
				.scale(self.targetCameraDistance / 5));
			self.dragStart = cursorPos;

			self.targetCameraPos = self.targetCameraPos.norm()
				.scale(self.targetCameraDistance);
		}

		{
			const cameraPoint = self.planet.transformedPoints[self.planet.getNearestPointTo(self.targetCameraPos)];
			if (self.cameraDistance < cameraPoint.length() + 100) {
				self.cameraDistance = cameraPoint.length() + 100;
			}
		}

		// Smooth camera move using linear interpolation
		self.targetCameraPos = self.targetCameraPos.norm()
			.scale(self.targetCameraDistance);
		if (!(
			std.math.approxEqAbs(f32, self.cameraPos.x(), self.targetCameraPos.x(), 0.01) and
			std.math.approxEqAbs(f32, self.cameraPos.y(), self.targetCameraPos.y(), 0.01) and
			std.math.approxEqAbs(f32, self.cameraPos.z(), self.targetCameraPos.z(), 0.01) and
			std.math.approxEqAbs(f32, self.cameraDistance, self.targetCameraDistance, 0.01)
		)) {
			// TODO: maybe use Quaternion lerp ? It could help on rotation near the poles.
			self.cameraPos = self.cameraPos.scale(0.9).add(self.targetCameraPos.scale(0.1));
			self.cameraDistance = self.cameraDistance * 0.9 + self.targetCameraDistance * 0.1;
			self.cameraPos = self.cameraPos.norm()
				.scale(self.cameraDistance);
		}

		const planet = &self.planet;

		var sunPhi: f32 = @floatCast(f32, @mod(self.gameTime / self.planetRotationTime, 2*std.math.pi));
		var sunTheta: f32 = std.math.pi / 2.0;
		var solarVector = Vec3.new(
			@cos(sunPhi) * @sin(sunTheta),
			@sin(sunPhi) * @sin(sunTheta),
			@cos(sunTheta)
		);

		planet.upload(game.loop, self.displayMode, self.axialTilt);

		const zFar = planet.radius * 5;
		const zNear = zFar / 10000;

		const right = self.cameraPos.cross(Vec3.forward()).norm();
		const forward = self.cameraPos.cross(right).norm().negate();
		const planetTarget = Vec3.new(0, 0, 0).sub(self.cameraPos).norm();
		const distToPlanet = self.cameraDistance - self.planet.radius;
		const target = self.cameraPos.add(Vec3.lerp(planetTarget, forward,
			std.math.pow(f32, 2, -distToPlanet / self.planet.radius * 5) * 0.6
		));

		// Start by rendering the skybox
		{
			const program = renderer.skyboxProgram;
			program.use();
			program.setUniformMat4("projMatrix",
				Mat4.perspective(70, size.x() / size.y(), 0.01, 100));
			var newViewMatrix = Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1));
			// remove all the translation part
			newViewMatrix.data[0][3] = 0;
			newViewMatrix.data[1][3] = 0;
			newViewMatrix.data[2][3] = 0;
			newViewMatrix.data[3][3] = 1;
			newViewMatrix.data[3][0] = 0;
			newViewMatrix.data[3][1] = 0;
			newViewMatrix.data[3][2] = 0;
			program.setUniformMat4("viewMatrix", newViewMatrix);
			gl.depthMask(gl.FALSE);

			gl.activeTexture(gl.TEXTURE0);
			gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.skyboxCubemap.texture);
			program.setUniformInt("skyboxCubemap", 0);

			gl.bindVertexArray(CubeMesh.getVAO());
			gl.drawArrays(gl.TRIANGLES, 0, 36);

			gl.depthMask(gl.TRUE);
		}

		// Then render the sun
		{
			// TODO: do like skybox so it looks infinitely far
			const program = renderer.sunProgram;
			program.use();
			program.setUniformMat4("projMatrix",
				Mat4.perspective(70, size.x() / size.y(), 1, 1000000));
			program.setUniformMat4("viewMatrix",
				Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));
			const modelMatrix = Mat4.recompose(solarVector.scale(300000), Vec3.new(0, 0, 0), Vec3.new(8000, 8000, 8000));
			program.setUniformMat4("modelMatrix",
				modelMatrix);

			const mesh = SunMesh.getMesh(game.allocator);
			gl.bindVertexArray(mesh.vao);
			gl.drawElements(gl.TRIANGLES, @intCast(c_int, mesh.indices.len), gl.UNSIGNED_INT, null);
		}

		// Then render the planet
		{
			const program = renderer.terrainProgram;
			program.use();
			program.setUniformMat4("projMatrix",
				Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
			program.setUniformMat4("viewMatrix",
				Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

			const modelMatrix = Mat4.recompose(Vec3.new(0, 0, 0), Vec3.new(0, 0, 0), Vec3.new(1, 1, 1));
			program.setUniformMat4("modelMatrix",
				modelMatrix);

			program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
			program.setUniformVec3("lightDir", solarVector);
			program.setUniformFloat("lightIntensity", self.solarConstant / 1500);
			program.setUniformVec3("viewPos", self.cameraPos);
			program.setUniformFloat("planetRadius", planet.radius);
			program.setUniformInt("displayMode", @enumToInt(self.displayMode)); // display mode
			program.setUniformInt("selectedVertex", @intCast(c_int, self.selectedPoint));
			program.setUniformFloat("kmPerWaterMass", planet.getKmPerWaterMass());

			gl.activeTexture(gl.TEXTURE0);
			gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.noiseCubemap.texture);
			program.setUniformInt("noiseCubemap", 0);

			const terrainNormalMap = renderer.textureCache.get("normal-map");
			gl.activeTexture(gl.TEXTURE1);
			gl.bindTexture(gl.TEXTURE_2D, terrainNormalMap.texture);
			program.setUniformInt("terrainNormalMap", 1);

			const waterNormalMap = renderer.textureCache.get("water-normal-map");
			gl.activeTexture(gl.TEXTURE2);
			gl.bindTexture(gl.TEXTURE_2D, waterNormalMap.texture);
			program.setUniformInt("waterNormalMap", 2);

			gl.enable(gl.CULL_FACE);
			defer gl.disable(gl.CULL_FACE);
			gl.frontFace(gl.CW);
			defer gl.frontFace(gl.CCW);

			gl.bindVertexArray(planet.mesh.vao);
			gl.drawElements(gl.TRIANGLES, planet.numTriangles, gl.UNSIGNED_INT, null);
		}

		const entity = renderer.entityProgram;
		entity.use();
		entity.setUniformMat4("projMatrix",
			Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
		entity.setUniformMat4("viewMatrix",
			Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

		gl.frontFace(gl.CCW);
		for (planet.lifeforms.items) |lifeform| {
			const modelMat = Mat4.recompose(lifeform.position, Vec3.new(0, 0, 0), Vec3.new(1, 1, 1));
			entity.setUniformMat4("modelMatrix",
				modelMat);
			entity.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
			entity.setUniformVec3("lightDir", solarVector);
			
			const mesh = lifeform.getMesh();
			gl.bindVertexArray(mesh.vao);
			gl.drawArrays(gl.TRIANGLES, 0, mesh.numTriangles);
		}
	}

	// As updated slices (temperature and water elevation) are updated by a
	// swap. This is atomic.
	pub fn update(self: *PlayState, game: *Game) void {
		const planet = &self.planet;

		var sunPhi: f32 = @floatCast(f32, @mod(self.gameTime / self.planetRotationTime, 2*std.math.pi));
		var sunTheta: f32 = std.math.pi / 2.0;
		var solarVector = Vec3.new(
			@cos(sunPhi) * @sin(sunTheta),
			@sin(sunPhi) * @sin(sunTheta),
			@cos(sunTheta)
		);

		if (self.selectedTool == .EmitWater and game.window.getMouseButton(.left) == .press) {
			const kmPerWaterMass = planet.getKmPerWaterMass();
			if (planet.waterMass[self.selectedPoint] < 25 / kmPerWaterMass) {
				planet.waterMass[self.selectedPoint] += 0.00005 * self.timeScale / kmPerWaterMass;
			}
		}
		if (self.selectedTool == .PlaceVegetation and game.window.getMouseButton(.left) == .press) {
			planet.vegetation[self.selectedPoint] = 1;
		}

		if (self.selectedTool == .DrainWater and game.window.getMouseButton(.left) == .press) {
			planet.waterMass[self.selectedPoint] = 0;
			for (planet.getNeighbours(self.selectedPoint)) |idx| {
				planet.waterMass[idx] = 0;
			}
		}

		if (self.selectedTool == .RaiseTerrain and game.window.getMouseButton(.left) == .press) {
			if (planet.elevation[self.selectedPoint] < planet.radius + 20) {
				planet.elevation[self.selectedPoint] += 0.4;
			}
			for (planet.getNeighbours(self.selectedPoint)) |idx| {
				if (planet.elevation[idx] < planet.radius + 20) {
					planet.elevation[idx] += 0.2;
				}
			}
		}

		if (self.selectedTool == .LowerTerrain and game.window.getMouseButton(.left) == .press) {
			if (planet.elevation[self.selectedPoint] > planet.radius - 20) {
				planet.elevation[self.selectedPoint] -= 0.4;
			}
			for (planet.getNeighbours(self.selectedPoint)) |idx| {
				if (planet.elevation[idx] > planet.radius - 20) {
					planet.elevation[idx] -= 0.2;
				}
			}
		}

		if (self.debug_clearWater) {
			std.mem.set(f32, self.planet.waterMass, 0);
			std.mem.set(f32, self.planet.waterVaporMass, 0);
			self.debug_clearWater = false;
		}

		if (self.debug_deluge) {
			std.mem.set(f32, self.planet.waterVaporMass, 500_000);
			self.debug_deluge = false;
		}

		if (!self.paused) {
			// TODO: variable simulation step

			const simulationSteps = 1;
			var i: usize = 0;
			while (i < simulationSteps) : (i += 1) {
				// The planet is simulated with a time scale divided by the number
				// of simulation steps. So that if there are more steps, the same
				// time speed is kept but the precision is increased.
				planet.simulate(game.loop, .{
					.solarConstant = self.solarConstant,
					.timeScale = self.timeScale / simulationSteps,
					.gameTime = self.gameTime,
					.planetRotationTime = self.planetRotationTime,
					.solarVector = solarVector,
				});
			}

			// TODO: use std.time.milliTimestamp or std.time.Timer for accurate game time
			self.gameTime += 0.016 * self.timeScale;
		}

		if (self.defer_saveGame) {
			self.saveGame() catch |err| {
				// TODO: handle error
				err catch {};
			};
			self.defer_saveGame = false;
		}
	}

	pub fn mousePressed(self: *PlayState, game: *Game, button: MouseButton) void {
		if (self.selectedTool == .PlaceLife and button == .left) {
			const planet = &self.planet;
			const point = self.selectedPoint;
			const pointPos = planet.transformedPoints[point];
			if (Lifeform.init(game.allocator, pointPos, .Rabbit, self.gameTime)) |lifeform| {
				planet.lifeformsLock.lock();
				defer planet.lifeformsLock.unlock();
				planet.lifeforms.append(lifeform) catch unreachable;
			} else |err| {
				std.log.err("Could not load Rabbit: {s}", .{ @errorName(err) });
				if (@errorReturnTrace()) |trace| {
					std.debug.dumpStackTrace(trace.*);
				}
			}
		}

		if (button == .right) {
			const cursorPos = game.window.getCursorPos() catch unreachable;
			self.dragStart = Vec2.new(@floatCast(f32, cursorPos.xpos), @floatCast(f32, cursorPos.ypos));
		}
		if (button == .middle) {
			const numEnumFields = std.meta.fields(Planet.DisplayMode).len;
			self.displayMode = @intToEnum(Planet.DisplayMode,
				@mod(@enumToInt(self.displayMode) + 1, numEnumFields)
			);
		}
	}

	pub fn mouseScroll(self: *PlayState, _: *Game, yOffset: f64) void {
		const zFar = self.planet.radius * 5;
		const zNear = zFar / 10000;

		const minDistance = self.planet.radius + zNear;
		const maxDistance = self.planet.radius * 5;
		self.targetCameraDistance = std.math.clamp(
			self.targetCameraDistance - (@floatCast(f32, yOffset) * self.cameraDistance / 50),
			minDistance, maxDistance);
	}

	pub fn mouseMoved(self: *PlayState, game: *Game, x: f32, y: f32) void {
		const windowSize = game.window.getFramebufferSize() catch unreachable;
		// Transform screen coordinates to Normalized Device Space coordinates
		const ndsX = 2 * x / @intToFloat(f32, windowSize.width) - 1;
		const ndsY = 1 - 2 * y / @intToFloat(f32, windowSize.height);
		var cursorVector = za.Vec4.new(ndsX, ndsY, -1, 1);

		// 'unproject' the coordinates by using the inversed projection matrix
		const zFar = self.planet.radius * 5;
		const zNear = zFar / 10000;
		const projMatrix = Mat4.perspective(70, @intToFloat(f32, windowSize.width) / @intToFloat(f32, windowSize.height), zNear, zFar);
		cursorVector = projMatrix.inv().mulByVec4(cursorVector);

		// put to world space by multiplying by inverse of view matrix
		cursorVector.data[2] = -1; cursorVector.data[3] = 0; // we only want directions so set z and w
		const viewMatrix = Mat4.lookAt(self.cameraPos, Vec3.new(0, 0, 0), Vec3.new(0, 0, 1));
		cursorVector = viewMatrix.inv().mulByVec4(cursorVector);
		const worldSpaceCursor = Vec3.new(cursorVector.x(), cursorVector.y(), cursorVector.z());
		//std.log.info("{d}", .{ worldSpaceCursor });

		// Select the closest point that the camera is facing.
		// To do this, it gets the point that has the lowest distance to the
		// position of the camera.
		const pos = self.cameraPos.add(worldSpaceCursor.scale(self.cameraPos.length()/2)).norm().scale(self.planet.radius + 20);
		var closestPointDist: f32 = std.math.inf_f32;
		var closestPoint: usize = undefined;
		for (self.planet.transformedPoints) |point, i| {
			if (point.distance(pos) < closestPointDist) {
				closestPoint = i;
				closestPointDist = point.distance(pos);
			}
		}
		self.selectedPoint = closestPoint;
	}

	pub fn renderUI(self: *PlayState, _: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;
		const ctx = &renderer.nkContext;
		nk.nk_style_default(ctx);

		if (nk.nk_begin(ctx, "Open Planet Control", .{ .x = 185, .y = 10, .w = 90, .h = 50 }, 
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_dynamic(ctx, 40, 1);
			if (nk.nk_button_label(ctx, "Control") != 0) {
				self.showPlanetControl = !self.showPlanetControl;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "Mean Temperature", .{ .x = 285, .y = 20, .w = 200, .h = 30 }, 
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			var prng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.milliTimestamp()));
			const random = prng.random();

			if (!self.paused) {
				var meanTemperature: f32 = 0;
				var i: usize = 0;
				while (i < 1000) : (i += 1) {
					const pointIdx = random.intRangeLessThanBiased(usize, 0, self.planet.temperature.len);
					meanTemperature += self.planet.temperature[pointIdx];
				}
				meanTemperature /= 1000;
				self.meanTemperature = self.meanTemperature * 0.9 + meanTemperature * 0.1;
			}

			nk.nk_layout_row_dynamic(ctx, 30, 1);
			var buf: [500]u8 = undefined;
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Mean Temp. : {d:.1}°C", .{ self.meanTemperature - 273.15 }) catch unreachable, nk.NK_TEXT_ALIGN_CENTERED);
		}
		nk.nk_end(ctx);

		if (self.showPlanetControl) {
			if (nk.nk_begin(ctx, "Planet Control",.{ .x = 30, .y = 70, .w = 450, .h = 400 },
			nk.NK_WINDOW_BORDER) != 0) {
				nk.nk_layout_row_dynamic(ctx, 50, 1);
				nk.nk_property_float(ctx, "Axial Tilt (deg)", 0, &self.axialTilt, 360, 1, 0.1);

				nk.nk_layout_row_dynamic(ctx, 50, 1);
				nk.nk_property_float(ctx, "Solar Constant (W/m²)", 0, &self.solarConstant, 5000, 100, 2);

				// TODO: instead of changing surface conductivity,
				// change the surface materials by using meteors and
				// others
				
				nk.nk_layout_row_dynamic(ctx, 50, 1);
				nk.nk_property_float(ctx, "Rotation Speed (s)", 10, &self.planetRotationTime, 1600000, 1000, 10);

				nk.nk_layout_row_dynamic(ctx, 50, 1);
				nk.nk_property_float(ctx, "Time Scale (game s / IRL s)", 0.5, &self.timeScale, 90000, 1000, 5);

				nk.nk_layout_row_dynamic(ctx, 50, 1);
				var buf: [200]u8 = undefined;
				nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "{d} lifeforms", .{ self.planet.lifeforms.items.len }) catch unreachable,
					nk.NK_TEXT_ALIGN_CENTERED);
				
				nk.nk_layout_row_dynamic(ctx, 50, 3);
				if (nk.nk_button_label(ctx, "Clear all water") != 0) {
					self.debug_clearWater = true;
				}
				if (nk.nk_button_label(ctx, "Deluge") != 0) {
					self.debug_deluge = true;
				}
				if (nk.nk_button_label(ctx, "Save game") != 0) {
					self.defer_saveGame = true;
				}
			}
			nk.nk_end(ctx);
		}

		if (nk.nk_begin(ctx, "Point Info", .{ .x = size.x() - 350, .y = size.y() - 300, .w = 300, .h = 270 },
			0) != 0) {
			var buf: [200]u8 = undefined;
			const point = self.selectedPoint;
			const planet = self.planet;

			nk.nk_layout_row_dynamic(ctx, 30, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Point #{d}", .{ point }) catch unreachable, nk.NK_TEXT_ALIGN_CENTERED);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Altitude: {d:.1} km", .{ planet.elevation[point] - planet.radius }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Water Mass: {:.1} kg", .{ planet.waterMass[point] * 1_000_000_000 }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
			// The units are given in centimeters, which is the equivalent amount of water that could be produced if all the water vapor in the column were to condense
			// similar to https://earthobservatory.nasa.gov/global-maps/MYDAL2_M_SKY_WV
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Water Vapor: {d:.1} cm", .{ planet.waterVaporMass[point] * 1_000_000_000 / planet.getMeanPointArea() * planet.getKmPerWaterMass() * 100_000 }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Temperature: {d:.3}°C", .{ planet.temperature[point] - 273.15 }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Point Area: {d}km²", .{ @floor(planet.getMeanPointArea() / 1_000_000) }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);

			nk.nk_layout_row_dynamic(ctx, 20, 1);
			const RH = Planet.getRelativeHumidity(planet.getSubstanceDivider(), planet.temperature[point], planet.waterVaporMass[point]);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Humidity: {d:.1}%", .{ RH * 100 }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);

			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Vapor Pressure: {d:.0} / {d:.0} Pa", .{ Planet.getWaterVaporPartialPressure(planet.getSubstanceDivider(), planet.temperature[point], planet.waterVaporMass[point]), Planet.getEquilibriumVaporPressure(planet.temperature[point]) }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);

			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Air Direction (km/h): {d:.1}, {d:.1}", .{ planet.airVelocity[point].x() * 3600, planet.airVelocity[point].y() * 3600 }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
		}
		nk.nk_end(ctx);

		// Transparent window style
		const windowColor = nk.nk_color { .r = 0, .g = 0, .b = 0, .a = 0 };
		_ = nk.nk_style_push_color(ctx, &ctx.style.window.background, windowColor);
		defer _ = nk.nk_style_pop_color(ctx);
		_ = nk.nk_style_push_style_item(ctx, &ctx.style.window.fixed_background, nk.nk_style_item_color(windowColor));
		defer _ = nk.nk_style_pop_style_item(ctx);

		if (nk.nk_begin(ctx, "Game Speed", .{ .x = size.x() - 150, .y = 50, .w = 90, .h = 60 }, 
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_dynamic(ctx, 40, 2);
			if (nk.nk_button_label(ctx, "||") != 0) {
				self.paused = true;
			}
			if (nk.nk_button_symbol(ctx, nk.NK_SYMBOL_TRIANGLE_RIGHT) != 0) {
				self.paused = false;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "No Tool", .{ .x = 550, .y = 10, .w = 70, .h = 70 },
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_static(ctx, 60, 60, 1);
			
			const waterIcon = renderer.textureCache.get("no-tool").toNkImage();
			if (nk.nk_button_image(ctx, waterIcon) != 0) {
				self.selectedTool = .None;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "Emit Water Tool", .{ .x = 625, .y = 10, .w = 70, .h = 70 },
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_static(ctx, 60, 60, 1);
			
			const waterIcon = renderer.textureCache.get("emit-water").toNkImage();
			if (nk.nk_button_image(ctx, waterIcon) != 0) {
				self.selectedTool = .EmitWater;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "Drain Water Tool", .{ .x = 700, .y = 10, .w = 70, .h = 70 },
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_static(ctx, 60, 60, 1);
			
			const waterIcon = renderer.textureCache.get("drain-water").toNkImage();
			if (nk.nk_button_image(ctx, waterIcon) != 0) {
				self.selectedTool = .DrainWater;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "Place Vegetation Tool", .{ .x = 775, .y = 10, .w = 70, .h = 70 },
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_static(ctx, 60, 60, 1);
			
			const waterIcon = renderer.textureCache.get("place-vegetation").toNkImage();
			if (nk.nk_button_image(ctx, waterIcon) != 0) {
				self.selectedTool = .PlaceVegetation;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "Raise Terrain Tool", .{ .x = 850, .y = 10, .w = 70, .h = 70 },
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_static(ctx, 60, 60, 1);
			
			const waterIcon = renderer.textureCache.get("place-vegetation").toNkImage();
			if (nk.nk_button_image(ctx, waterIcon) != 0) {
				self.selectedTool = .RaiseTerrain;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "Lower Terrain Tool", .{ .x = 925, .y = 10, .w = 70, .h = 70 },
			nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_static(ctx, 60, 60, 1);
			
			const waterIcon = renderer.textureCache.get("place-vegetation").toNkImage();
			if (nk.nk_button_image(ctx, waterIcon) != 0) {
				self.selectedTool = .LowerTerrain;
			}
		}
		nk.nk_end(ctx);
	}

	pub fn saveGame(self: *PlayState) !void {
		try std.fs.cwd().makePath("saves/abc");

		const metadataFile = try std.fs.cwd().createFile("saves/abc/metadata.json", .{});
		defer metadataFile.close();
		const GameMetadata = struct {
			format_version: u32 = 0,
			game_time: f64,
			axial_tilt: f32,
			solar_constant: f32,
			planet_rotation_time: f32,
			time_scale: f32,
			radius: f32,
			subdivisions: u64,
			seed: u64,
		};
		try std.json.stringify(GameMetadata {
			.format_version = 0,
			.game_time = self.gameTime,
			.axial_tilt = self.axialTilt,
			.solar_constant = self.solarConstant,
			.planet_rotation_time = self.planetRotationTime,
			.time_scale = self.timeScale,
			.radius = self.planet.radius,
			.subdivisions = self.planet.numSubdivisions,
			.seed = self.planet.seed,
		}, .{ .whitespace = .{ .indent = .Tab }}, metadataFile.writer());
		
		const planetFile = try std.fs.cwd().createFile("saves/abc/planet.dat", .{});
		defer planetFile.close();

		var buffer = std.io.bufferedWriter(planetFile.writer());
		const writer = buffer.writer();
		const planet = self.planet;
		// planet.vertices can be re-generated using icosphere data, same for indices

		for (planet.elevation) |elevation| {
			try writer.writeIntLittle(u32, @bitCast(u32, elevation));
		}

		for (planet.temperature) |temperature| {
			try writer.writeIntLittle(u32, @bitCast(u32, temperature));
		}

		for (planet.vegetation) |vegetation| {
			try writer.writeIntLittle(u32, @bitCast(u32, vegetation));
		}

		for (planet.waterMass) |waterMass| {
			try writer.writeIntLittle(u32, @bitCast(u32, waterMass));
		}

		for (planet.waterVaporMass) |waterVaporMass| {
			try writer.writeIntLittle(u32, @bitCast(u32, waterVaporMass));
		}

		for (planet.airVelocity) |airVelocity| {
			try writer.writeIntLittle(u32, @bitCast(u32, airVelocity.x()));
			try writer.writeIntLittle(u32, @bitCast(u32, airVelocity.y()));
		}

		// TODO: save lifeforms

		try buffer.flush();
	}

	pub fn deinit(self: *PlayState) void {
		self.planet.deinit();
	}

};
