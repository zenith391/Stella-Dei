const std = @import("std");
const nvg = @import("nanovg");
const Game = @import("main.zig").Game;

const colors = struct {
	const main = nvg.rgb(255, 255, 255);
};

pub const UiComponentState = union(enum) {
	Button: struct {
		color: nvg.Color, 
	}
};

pub fn button(vg: nvg, game: *Game, name: []const u8, x: f32, y: f32, w: f32, h: f32, text: []const u8) bool {
	const cursor = game.window.getCursorPos() catch unreachable;
	const pressed = game.window.getMouseButton(.left) == .press;
	const hovered = cursor.xpos >= x and cursor.ypos >= y and cursor.xpos < x + w and cursor.ypos < y + h;
	var state = game.imgui_state.get(name) orelse UiComponentState { .Button = .{
		.color = colors.main
	}};
	defer game.imgui_state.put(name, state) catch {};

	const targetColor = if (hovered) nvg.rgb(200, 200, 200) else colors.main;
	state.Button.color = nvg.lerpRGBA(state.Button.color, targetColor, 1 - 0.2);
	const colorGradBottom = nvg.lerpRGBA(state.Button.color, nvg.rgb(0,0,0), 1 - 0.2);

	vg.beginPath();
	vg.fillPaint(vg.linearGradient(x, y, x, y+h, state.Button.color, colorGradBottom));
	vg.roundedRect(x, y, w, h, 10);
	vg.fill();

	vg.fontSize(20.0);
	vg.fontFace("sans-serif");
	vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
	vg.fillColor(nvg.rgb(0, 0, 0));
	vg.fontBlur(if (hovered) 0 else 0.5);
	_ = vg.text(x + w / 2, y + h / 2, text);

	return hovered and pressed;
}
