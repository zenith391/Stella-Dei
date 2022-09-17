const std = @import("std");
const nvg = @import("nanovg");
const Game = @import("main.zig").Game;

const colors = struct {
	const main = nvg.rgb(255, 255, 255);
};


pub fn button(vg: nvg, game: *Game, x: f32, y: f32, w: f32, h: f32, text: []const u8) bool {
	const cursor = game.window.getCursorPos() catch unreachable;
	const pressed = game.window.getMouseButton(.left) == .press;

	vg.beginPath();
	vg.fillColor(colors.main);
	if (cursor.xpos >= x and cursor.ypos >= y and cursor.xpos < x+w and cursor.ypos < y+h) {
		vg.fillColor(comptime nvg.rgb(200, 200, 200));
		if (pressed)
			return true;
	}

	vg.rect(x, y, w, h);
	vg.fill();

	vg.beginPath();
	vg.fillColor(comptime nvg.rgb(0, 0, 0));
	_ = vg.text(x, y, text);
	vg.fill();

	return false;
}
