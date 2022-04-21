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

pub const PlayState = struct {
	/// The position of the camera
	/// This is already scaled by cameraDistance
	cameraPos: Vec3 = Vec3.new(0, -8, 2),
	/// The previous mouse position that was recorded during dragging (to move the camera).
	dragStart: Vec2,
	planet: Planet,
	/// Noise cubemap used for rendering terrains with a terrain quality that
	/// seems higher than it is really.
	cubemap: Texture,

	/// The distance the camera is from the planet's center
	cameraDistance: f32,
	/// The target camera distance, every frame, a linear interpolation is done
	/// between the current camera distance and the target distance, to create a
	/// smooth (de)zooming effect.
	targetCameraDistance: f32,
	/// The index of the currently selected point
	selectedPoint: usize = 0,
	displayMode: PlanetDisplayMode = .Normal,
	/// Inclination of rotation, in radians
	planetInclination: f32 = 0.4,
	/// The solar constant in W.m-2
	solarConstant: f32 = 1361,
	/// The planet's surface conductivity in arbitrary units (TODO: use real unit)
	conductivity: f32 = 0.25,
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

	/// When enabled, emits water at point 123
	debug_emitWater: bool = false,
	/// When enabled, drains all water at points 100 to 150
	debug_suckWater: bool = false,

	const PlanetDisplayMode = enum(c_int) {
		Normal = 0,
		Temperature = 1,
	};

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

		// TODO: make a loading scene
		const planetRadius = 5000; // a radius a bit smaller than Earth's (~6371km)
		const seed = randomPrng.random().int(u32);
		const planet = Planet.generate(game.allocator, 5, planetRadius, seed) catch unreachable;

		const cursorPos = game.window.getCursorPos() catch unreachable;
		return PlayState {
			.dragStart = Vec2.new(@floatCast(f32, cursorPos.xpos), @floatCast(f32, cursorPos.ypos)),
			.cubemap = cubemap,
			.planet = planet,
			.targetCameraDistance = planetRadius * 2.5,
			.cameraDistance = planetRadius * 5,
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
			const right = self.cameraPos.cross(Vec3.forward()).norm();
			const backward = self.cameraPos.cross(right).norm();
			self.cameraPos = self.cameraPos
				.add(right.scale(delta.x())
				.add(backward.scale(-delta.y()))
				.scale(self.cameraDistance / 5));
			self.dragStart = cursorPos;

			self.cameraPos = self.cameraPos.norm()
				.scale(self.cameraDistance);
		}

		// Smooth (de)zooming using linear interpolation
		if (!std.math.approxEqAbs(f32, self.cameraDistance, self.targetCameraDistance, 0.01)) {
			self.cameraDistance = self.cameraDistance * 0.9 + self.targetCameraDistance * 0.1;
			self.cameraPos = self.cameraPos.norm()
				.scale(self.cameraDistance);
		}

		const planet = &self.planet;

		var sunPhi: f32 = @floatCast(f32, @mod(self.gameTime / self.planetRotationTime, 2*std.math.pi));
		var sunTheta: f32 = std.math.pi / 2.0;
		var solarVector = Vec3.new(
			std.math.cos(sunPhi) * std.math.sin(sunTheta),
			std.math.sin(sunPhi) * std.math.sin(sunTheta),
			std.math.cos(sunTheta)
		);

		if (!self.paused) {
			planet.upload(game.loop);
		}

		const program = renderer.terrainProgram;
		const zFar = planet.radius * 5;
		const zNear = zFar / 10000;
		program.use();
		program.setUniformMat4("projMatrix",
			Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
		
		const target = Vec3.new(0, 0, 0);
		program.setUniformMat4("viewMatrix",
			Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

		const modelMatrix = Mat4.recompose(Vec3.new(0, 0, 0), Vec3.new(0, 0, 0), Vec3.new(1, 1, 1));
		program.setUniformMat4("modelMatrix",
			modelMatrix);

		program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
		program.setUniformVec3("lightDir", solarVector);
		program.setUniformVec3("viewPos", self.cameraPos);
		program.setUniformFloat("planetRadius", planet.radius);
		program.setUniformInt("displayMode", @enumToInt(self.displayMode)); // display temperature

		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.cubemap.texture);
		program.setUniformInt("noiseCubemap", 0);

		gl.bindVertexArray(planet.vao);
		gl.drawElements(gl.TRIANGLES, planet.numTriangles, gl.UNSIGNED_INT, null);

		const entity = renderer.entityProgram;
		entity.use();
		entity.setUniformMat4("projMatrix",
			Mat4.perspective(70, size.x() / size.y(), 0.1, 1000.0));
		program.setUniformMat4("viewMatrix",
			Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

		for (planet.lifeforms.items) |lifeform| {
			const modelMat = Mat4.recompose(lifeform.position, Vec3.new(0, 0, 0), Vec3.new(1, 1, 1));
			program.setUniformMat4("modelMatrix",
				modelMat);
			
			gl.drawElements(gl.TRIANGLES, planet.numTriangles, gl.UNSIGNED_INT, null);
		}
	}

	// As updated slices (temperature and water elevation) are updated by a
	// swap. This is atomic.
	pub fn update(self: *PlayState, game: *Game) void {
		const planet = &self.planet;

		var sunPhi: f32 = @floatCast(f32, @mod(self.gameTime / self.planetRotationTime, 2*std.math.pi));
		var sunTheta: f32 = std.math.pi / 2.0;
		var solarVector = Vec3.new(
			std.math.cos(sunPhi) * std.math.sin(sunTheta),
			std.math.sin(sunPhi) * std.math.sin(sunTheta),
			std.math.cos(sunTheta)
		);

		if (!self.paused) {
			// TODO: variable simulation step

			const simulationSteps = 1;
			var i: usize = 0;
			while (i < simulationSteps) : (i += 1) {
				if (self.debug_emitWater) {
					planet.waterElevation[123] += 0.05 * self.timeScale / (self.timeScale / 10);
				}
				if (self.debug_suckWater) {
					var j: usize = 100;
					while (j < 150) : (j += 1) {
						planet.waterElevation[j] = 0;
					}
				}

				// The planet is simulated with a time scale divided by the number
				// of simulation steps. So that if there are more steps, the same
				// time speed is kept but the precision is increased.
				planet.simulate(game.loop, solarVector, .{
					.solarConstant = self.solarConstant,
					.conductivity = self.conductivity,
					.timeScale = self.timeScale / simulationSteps,
				});
			}

			// TODO: use std.time.milliTimestamp or std.time.Timer for accurate game time
			self.gameTime += 0.016 * self.timeScale;
		}
	}

	pub fn mousePressed(self: *PlayState, game: *Game, button: MouseButton) void {
		if (button == .right) {
			const cursorPos = game.window.getCursorPos() catch unreachable;
			self.dragStart = Vec2.new(@floatCast(f32, cursorPos.xpos), @floatCast(f32, cursorPos.ypos));
		}
		if (button == .middle) {
			if (self.displayMode == .Normal) {
				self.displayMode = .Temperature;
			} else if (self.displayMode == .Temperature) {
				self.displayMode = .Normal;
			}
		}

		// TODO: avoid interfering with the UI system
		if (button == .left) {
			const pos = self.cameraPos.norm().scale(self.planet.radius);
			var closestPointDist: f32 = std.math.inf_f32;
			var closestPoint: usize = undefined;
			for (self.planet.vertices) |point, i| {
				if (point.distance(pos) < closestPointDist) {
					closestPoint = i;
					closestPointDist = point.distance(pos);
				}
			}
			self.selectedPoint = closestPoint;
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

	// NOTE: `mouseMoved` event handler is not yet implemented
	pub fn mouseMoved(self: *PlayState, _: *Game, x: f32, y: f32) void {
		_ = x;
		_ = y;

		// Select the closest point that the camera is facing.
		// To do this, it gets the point that has the lowest distance to the
		// position of the camera.
		const pos = self.cameraPos.norm().scale(self.planet.radius);
		var closestPointDist: f32 = std.math.inf_f32;
		var closestPoint: usize = undefined;
		for (self.planet.vertices) |point, i| {
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

		if (nk.nk_begin(ctx, "Planet Control", .{ .x = 100, .y = 100, .w = 600, .h = 150}, 
			nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE) != 0) {
			// currently unusable
			//nk.nk_layout_row_dynamic(ctx, 50, 1);
			//nk.nk_property_float(ctx, "Planet Inclination (rad)", 0, &self.planetInclination, 3.14, 0.1, 0.01);

			nk.nk_layout_row_dynamic(ctx, 50, 1);
			nk.nk_property_float(ctx, "Solar Constant (W/m²)", 0, &self.solarConstant, 5000, 1, 0.2);

			// currently unusable
			//nk.nk_layout_row_dynamic(ctx, 50, 1);
			//nk.nk_property_float(ctx, "Surface Conductivity", 0.0001, &self.conductivity, 1, 0.1, 0.001);
			
			nk.nk_layout_row_dynamic(ctx, 50, 1);
			nk.nk_property_float(ctx, "Rotation Speed (s)", 10, &self.planetRotationTime, 160000, 1000, 10);

			nk.nk_layout_row_dynamic(ctx, 50, 1);
			nk.nk_property_float(ctx, "Time Scale (game s / IRL s)", 0.5, &self.timeScale, 40000, 1000, 5);

			nk.nk_layout_row_dynamic(ctx, 50, 2);
			self.debug_emitWater = nk.nk_check_label(ctx, "Debug: Emit Water", @boolToInt(self.debug_emitWater)) != 0;
			self.debug_suckWater = nk.nk_check_label(ctx, "Debug: Suck Water", @boolToInt(self.debug_suckWater)) != 0;

			if (nk.nk_button_label(&renderer.nkContext, "Place lifeform") != 0) {
				const point = self.selectedPoint;
				const planet = &self.planet;
				const pointPos = planet.vertices[point].scale(planet.elevation[point] + 0.05);
				planet.lifeforms.append(Lifeform.init(pointPos)) catch unreachable;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "Point Info", .{ .x = size.x() - 350, .y = size.y() - 200, .w = 300, .h = 150 },
			0) != 0) {
			var buf: [200]u8 = undefined;
			const point = self.selectedPoint;
			const planet = self.planet;

			nk.nk_layout_row_dynamic(ctx, 30, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Point #{d}", .{ point }) catch unreachable, nk.NK_TEXT_ALIGN_CENTERED);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			// sea level is meant to be = radius - 1
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Altitude: {d:.1} km", .{ planet.elevation[point] - planet.radius + 1 }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Water Elevation: {d:.1} km", .{ planet.waterElevation[point] }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Temperature: {d:.3}°C", .{ planet.temperature[point] - 273.15 }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
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
	}

	pub fn deinit(self: *PlayState) void {
		self.planet.deinit();
	}

};
