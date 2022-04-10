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
	rot: f32 = 0,
	cameraPos: Vec3 = Vec3.new(0, -8, 2),
	dragStart: Vec2,
	planet: ?Planet = null,
	cubemap: Texture,

	cameraDistance: f32 = 1000,
	targetCameraDistance: f32 = 30,
	/// The index of the currently selected point
	selectedPoint: usize = 0,
	displayMode: PlanetDisplayMode = .Normal,
	/// Inclination of rotation, in radians
	planetInclination: f32 = 0.4,
	sunPower: f32 = 0.4,
	conductivity: f32 = 0.25,
	/// The time it takes for the planet to do a full rotation, in seconds
	planetRotationTime: f32 = 1,
	/// Game time in seconds
	gameTime: f64 = 0,
	timeScale: f32 = 1,
	paused: bool = false,
	debug_emitWater: bool = false,
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
		nk.nk_style_default(&game.renderer.nkContext);

		const cubemap = Texture.initCubemap();
		var data: []u8 = game.allocator.alloc(u8, 512 * 512 * 3) catch unreachable;
		defer game.allocator.free(data);

		var random = std.rand.DefaultPrng.init(1234);

		const faces = [_]Texture.CubemapFace { .PositiveX, .NegativeX, .PositiveY, .NegativeY, .PositiveZ, .NegativeZ };
		for (faces) |face| {
			var y: usize = 0;
			while (y < 512) : (y += 1) {
				var x: usize = 0;
				while (x < 512) : (x += 1) {
					data[(y*512+x)*3+0] = random.random().int(u8);
				}
			}
			cubemap.setCubemapFace(face, 512, 512, data);
		}

		const cursorPos = game.window.getCursorPos() catch unreachable;
		return PlayState {
			.dragStart = Vec2.new(@floatCast(f32, cursorPos.xpos), @floatCast(f32, cursorPos.ypos)),
			.cubemap = cubemap,
		};
	}

	pub fn render(self: *PlayState, game: *Game, renderer: *Renderer) void {
		const window = renderer.window;
		const size = renderer.framebufferSize;

		if (window.getMouseButton(.right) == .press) {
			const glfwCursorPos = game.window.getCursorPos() catch unreachable;
			const cursorPos = Vec2.new(@floatCast(f32, glfwCursorPos.xpos), @floatCast(f32, glfwCursorPos.ypos));
			const delta = cursorPos.sub(self.dragStart).scale(1 / 100.0);
			const right = self.cameraPos.cross(Vec3.forward()).norm();
			const forward = self.cameraPos.cross(Vec3.right()).norm();
			self.cameraPos = self.cameraPos.add(
				 right.scale(delta.x())
				.add(forward.scale(delta.y()))
				.scale(self.cameraDistance / 5));
			self.dragStart = cursorPos;

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
			self.planet = Planet.generate(game.allocator, 5) catch unreachable;
			self.planet.?.upload();
		}
		var planet = &self.planet.?;

		var sunPhi: f32 = @floatCast(f32, @mod(self.gameTime / self.planetRotationTime, 2*std.math.pi));
		//var sunTheta: f32 = self.planetInclination;
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
					planet.waterElevation[123] += 0.05 * self.timeScale;
				}
				if (self.debug_suckWater) {
					var j: usize = 100;
					while (j < 150) : (j += 1) {
						planet.waterElevation[j] = 0;
					}
				}

				planet.simulate(solarVector, .{
					.sunPower = self.sunPower,
					.conductivity = self.conductivity,
					.timeScale = self.timeScale / simulationSteps,
				});
			}
			planet.upload();

			// TODO: use std.time.milliTimestamp or std.time.Timer for accurate game time
			self.gameTime += 0.016 * self.timeScale;
		}

		const program = renderer.terrainProgram;
		program.use();
		program.setUniformMat4("projMatrix",
			Mat4.perspective(70, size.x() / size.y(), 0.1, 1000.0));
		
		const target = Vec3.new(0, 0, 0);
		program.setUniformMat4("viewMatrix",
			Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

		const modelMatrix = Mat4.recompose(Vec3.new(0, 0, 0), Vec3.new(0, 0, 0), Vec3.new(20, 20, 20));
		program.setUniformMat4("modelMatrix",
			modelMatrix);

		program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
		program.setUniformVec3("lightDir", solarVector);
		program.setUniformVec3("viewPos", self.cameraPos);
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
			const pos = self.cameraPos;
			var closestPointDist: f32 = std.math.inf_f32;
			var closestPoint: usize = undefined;
			for (self.planet.?.vertices) |point, i| {
				if (point.distance(pos) < closestPointDist) {
					closestPoint = i;
					closestPointDist = point.distance(pos);
				}
			}
			self.selectedPoint = closestPoint;
		}
	}

	pub fn mouseScroll(self: *PlayState, _: *Game, yOffset: f64) void {
		self.targetCameraDistance = std.math.clamp(
			self.targetCameraDistance - @floatCast(f32, yOffset), 21, 100);
	}

	pub fn mouseMoved(self: *PlayState, _: *Game, x: f32, y: f32) void {
		_ = x;
		_ = y;

		const pos = self.cameraPos;
		var closestPointDist: f32 = std.math.inf_f32;
		var closestPoint: usize = undefined;
		for (self.planet.?.vertices) |point, i| {
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

		if (nk.nk_begin(ctx, "Planet Control", .{ .x = 100, .y = 100, .w = 600, .h = 150}, 
			nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE) != 0) {
			nk.nk_layout_row_dynamic(ctx, 50, 1);
			nk.nk_property_float(ctx, "Planet Inclination (rad)", 0, &self.planetInclination, 3.14, 0.1, 0.01);

			nk.nk_layout_row_dynamic(ctx, 50, 1);
			nk.nk_property_float(ctx, "Sun Power (W)", 0, &self.sunPower, 10, 0.01, 0.002);

			nk.nk_layout_row_dynamic(ctx, 50, 1);
			nk.nk_property_float(ctx, "Surface Conductivity", 0.0001, &self.conductivity, 1, 0.1, 0.001);
			
			nk.nk_layout_row_dynamic(ctx, 50, 1);
			nk.nk_property_float(ctx, "Rotation Speed (s)", 0.05, &self.planetRotationTime, 60000, 1, 0.01);

			nk.nk_layout_row_dynamic(ctx, 50, 1);
			nk.nk_property_float(ctx, "Time Scale", 0.05, &self.timeScale, 1, 0.1, 0.002);

			nk.nk_layout_row_dynamic(ctx, 50, 2);
			self.debug_emitWater = nk.nk_check_label(ctx, "Debug: Emit Water", @boolToInt(self.debug_emitWater)) != 0;
			self.debug_suckWater = nk.nk_check_label(ctx, "Debug: Suck Water", @boolToInt(self.debug_suckWater)) != 0;

			if (nk.nk_button_label(&renderer.nkContext, "Place lifeform") != 0) {
				const point = self.selectedPoint;
				const planet = &self.planet.?;
				const pointPos = planet.vertices[point].scale(20 * planet.elevation[point] + 0.05);
				planet.lifeforms.append(Lifeform.init(pointPos)) catch unreachable;
			}
		}
		nk.nk_end(ctx);

		if (nk.nk_begin(ctx, "Point Info", .{ .x = size.x() - 350, .y = size.y() - 200, .w = 300, .h = 150 },
			0) != 0) {
			var buf: [200]u8 = undefined;
			const point = self.selectedPoint;
			const planet = self.planet.?;

			nk.nk_layout_row_dynamic(ctx, 30, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Point #{d}", .{ point }) catch unreachable, nk.NK_TEXT_ALIGN_CENTERED);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Elevation: {d:.3}", .{ planet.elevation[point] }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
			nk.nk_layout_row_dynamic(ctx, 20, 1);
			nk.nk_label(ctx, std.fmt.bufPrintZ(&buf, "Water Elevation: {d:.3}", .{ planet.waterElevation[point] }) catch unreachable, nk.NK_TEXT_ALIGN_LEFT);
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
		if (self.planet) |planet| {
			planet.deinit();
		}
	}

};
