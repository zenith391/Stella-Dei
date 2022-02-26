const std = @import("std");
const nk = @import("../nuklear.zig");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const MouseButton = @import("../glfw.zig").MouseButton;

pub const MainMenuState = struct {

	pub fn init(_: *Game) MainMenuState {
		return MainMenuState {};
	}

	pub fn render(_: *MainMenuState, _: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;

		renderer.drawTexture("sun", size.x() / 2 - 125, size.y() / 2 - 125, 250, 250, 0);
	}

	pub fn renderUI(_: *MainMenuState, game: *Game, renderer: *Renderer) void {
		const size = renderer.framebufferSize;
		const windowRect = nk.struct_nk_rect { .x = size.x() - 350, .y = 50, .w = 300, .h = size.y() - 100 };

		const windowColor = nk.nk_color { .r = 0, .g = 0, .b = 0, .a = 0 };
		renderer.nkContext.style.window.background = windowColor;
		renderer.nkContext.style.window.fixed_background = nk.nk_style_item_color(windowColor);
		
		if (nk.nk_begin(&renderer.nkContext, "Main Menu", windowRect, 0) != 0) {
			nk.nk_layout_row_dynamic(&renderer.nkContext, 50, 1);
			nk.nk_label(&renderer.nkContext, "Name Not Included", nk.NK_TEXT_ALIGN_CENTERED);

			if (nk.nk_button_label(&renderer.nkContext, "Play") != 0) {
				game.setState(@import("play.zig").PlayState);
			}

			if (nk.nk_button_label(&renderer.nkContext, "Exit") != 0) {
				game.window.setShouldClose(true);
			}
		}
		nk.nk_end(&renderer.nkContext);
	}

};
