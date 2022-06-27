const std = @import("std");
const gl = @import("gl");
const nk = @import("../nuklear.zig");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const MainMenuState = @import("main_menu.zig").MainMenuState;

pub const SplashScreenState = struct {
	start: i64,

	pub fn init(game: *Game) SplashScreenState {
		const soundTrack = @import("../audio.zig").SoundTrack { .items = &.{
			"assets/intro.mp3",
		}};
		game.audio.playSoundTrackIn(soundTrack, 1000);
		return SplashScreenState {
			.start = std.time.milliTimestamp()
		};
	}

	pub fn render(self: *SplashScreenState, game: *Game, renderer: *Renderer) void {
		const elapsedTime = @intToFloat(f32, std.time.milliTimestamp() - self.start) / 1000;
		const gamma = 2.2;
		const luminosity = std.math.pow(f32,
			std.math.clamp((elapsedTime - 2) / 6, 0.0, 1.0),
			1.0 / gamma);
		const fadeOut = 1 - std.math.clamp((elapsedTime - 10) / 4, 0.0, 1.0);
		gl.clearColor(luminosity * fadeOut, luminosity * fadeOut, luminosity * fadeOut, 1.0);
		gl.clear(gl.COLOR_BUFFER_BIT);
		_ = renderer;

		if (elapsedTime > 15) {
			game.setState(MainMenuState);
		}
	}

	pub fn renderUI(self: *SplashScreenState, _: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;
		const logo = renderer.textureCache.get("pixelguys");

		const imageWidth: f32 = 1134.0 / 2.0;
		const imageHeight: f32 = 756.0 / 2.0;
		const windowRect = nk.struct_nk_rect { .x = size.x() / 2 - imageWidth / 2, .y = size.y() / 2 - imageHeight / 2, .w = imageWidth, .h = imageHeight };

		const windowColor = nk.nk_color { .r = 0, .g = 0, .b = 0, .a = 0 };
		renderer.nkContext.style.window.background = windowColor;
		renderer.nkContext.style.window.fixed_background = nk.nk_style_item_color(windowColor);
		
		if (nk.nk_begin(&renderer.nkContext, "Logo", windowRect, nk.NK_WINDOW_NO_SCROLLBAR) != 0) {
			nk.nk_layout_row_static(&renderer.nkContext, imageHeight, @floatToInt(c_int, imageWidth), 1);

			const elapsedTime = @intToFloat(f32, std.time.milliTimestamp() - self.start) / 1000;
			const alpha = std.math.clamp((elapsedTime - 8) / 2, 0.0, 1.0);
			const fadeOut = 1 - std.math.clamp((elapsedTime - 10) / 4, 0.0, 1.0);
			const imageColor = nk.nk_color { .r = 255, .g = 255, .b = 255, .a = @floatToInt(u8, alpha * fadeOut * 255) };
			nk.nk_image_color(&renderer.nkContext, logo.toNkImage(), imageColor);
		}
		nk.nk_end(&renderer.nkContext);
	}

};
