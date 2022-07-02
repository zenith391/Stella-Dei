const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const nk = @import("../nuklear.zig");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const PlayState = @import("play.zig").PlayState;

const Planet = @import("../simulation/planet.zig").Planet;

const Job = @import("../loop.zig").Job;

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

pub const MainMenuState = struct {
	planet: Planet,

	pub fn init(game: *Game) MainMenuState {
		const soundTrack = @import("../audio.zig").SoundTrack { .items = &.{
			"assets/music-main-menu.mp3",
		}};
		game.audio.playSoundTrackIn(soundTrack, 3000);

		var randomPrng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.milliTimestamp()));
		const seed = randomPrng.random().int(u64);
		const planet = Planet.generate(game.allocator, 7, 5000, seed) catch unreachable;

		return MainMenuState {
			.planet = planet
		};
	}

	pub fn render(self: *MainMenuState, game: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;
		const planet = &self.planet;
		const sunAngle = za.toRadians(@as(f32, 195.0));

		const sunPhi = @floatCast(f32, @mod(sunAngle, 2*std.math.pi));
		const sunTheta = za.toRadians(@as(f32, 90.0));
		const solarVector = Vec3.new(
			@cos(sunPhi) * @sin(sunTheta),
			@sin(sunPhi) * @sin(sunTheta),
			@cos(sunTheta)
		);

		const zFar = planet.radius * 5;
		const zNear = zFar / 10000;

		var cameraPos = Vec3.new(-802, -913, 292)
			.norm().scale(10000);

		const planetTarget = Vec3.new(0, 0, 0).sub(cameraPos).norm();
		const target = planetTarget;

		// Then render the planet
		{
			const program = renderer.terrainProgram;
			program.use();
			program.setUniformMat4("projMatrix",
				Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
			program.setUniformMat4("viewMatrix",
				Mat4.lookAt(cameraPos, target, Vec3.new(0, 0, 1)));
			
			const rot = @floatCast(f32, @mod(@intToFloat(f64, std.time.milliTimestamp()) / 1000.0
				/ 0.5, 360));
			const modelMatrix = Mat4.recompose(Vec3.new(0, 0, 0), Vec3.new(0, 0, rot), Vec3.new(1, 1, 1));
			program.setUniformMat4("modelMatrix",
				modelMatrix);

			program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
			program.setUniformVec3("lightDir", solarVector);
			program.setUniformFloat("lightIntensity", 1);
			program.setUniformVec3("viewPos", cameraPos);
			program.setUniformFloat("planetRadius", planet.radius);
			program.setUniformInt("displayMode", 0);
			program.setUniformInt("selectedVertex", 0);
			program.setUniformFloat("kmPerWaterMass", planet.getKmPerWaterMass());

			gl.activeTexture(gl.TEXTURE0);
			//gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.noiseCubemap.texture);
			program.setUniformInt("noiseCubemap", 0);

			const terrainNormalMap = renderer.textureCache.getExt("normal-map", .{ .mipmaps = true });
			gl.activeTexture(gl.TEXTURE1);
			gl.bindTexture(gl.TEXTURE_2D, terrainNormalMap.texture);
			program.setUniformInt("terrainNormalMap", 1);

			const waterNormalMap = renderer.textureCache.getExt("water-normal-map", .{ .mipmaps = true });
			gl.activeTexture(gl.TEXTURE2);
			gl.bindTexture(gl.TEXTURE_2D, waterNormalMap.texture);
			program.setUniformInt("waterNormalMap", 2);

			gl.enable(gl.CULL_FACE);
			defer gl.disable(gl.CULL_FACE);
			gl.frontFace(gl.CW);
			defer gl.frontFace(gl.CCW);

			planet.render(game.loop, .Normal, 0);
		}
	}

	pub fn renderUI(_: *MainMenuState, game: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;
		const windowRect = nk.struct_nk_rect { .x = size.x() / 2 - 150, .y = 50, .w = 300, .h = size.y() - 100 };

		const windowColor = nk.nk_color { .r = 0, .g = 0, .b = 0, .a = 0 };
		renderer.nkContext.style.window.background = windowColor;
		renderer.nkContext.style.window.fixed_background = nk.nk_style_item_color(windowColor);
		
		if (nk.nk_begin(&renderer.nkContext, "Main Menu", windowRect, 0) != 0) {
			nk.nk_layout_row_dynamic(&renderer.nkContext, 50, 1);
			nk.nk_label(&renderer.nkContext, "Stella Dei", nk.NK_TEXT_ALIGN_CENTERED);

			if (nk.nk_button_label(&renderer.nkContext, "Play") != 0) {
				// Sets the game state to play (that is, start the game)
				// To see the code, look in src/states/play.zig
				const job = Job(void).create(game.loop) catch unreachable;
				job.call(switchToPlay, .{ game }) catch unreachable;
				game.deinitJob = job;
			}

			if (nk.nk_button_label(&renderer.nkContext, "Exit") != 0) {
				game.window.setShouldClose(true);
			}
		}
		nk.nk_end(&renderer.nkContext);
	}

	fn switchToPlay(game: *Game) void {
		game.setState(PlayState);
	}

	pub fn deinit(self: *MainMenuState, game: *Game) void {
		_ = game;
		self.planet.deinit();
	}

};
