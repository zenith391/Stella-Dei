const std  = @import("std");
const gl   = @import("gl");
const glfw = @import("glfw.zig");
const za   = @import("zalgebra");

const Renderer = @import("renderer.zig").Renderer;
const Texture = @import("renderer.zig").Texture;

var renderer: Renderer = undefined;
var texture: Texture = undefined;

const MainMenuState = @import("states/main_menu.zig").MainMenuState;

pub const GameState = union(enum) {
	MainMenu: MainMenuState
};

pub const Game = struct {
	state: GameState
};

var game: Game = undefined;

fn render(window: glfw.Window) void {
	const size = window.getFramebufferSize();
	gl.viewport(0, 0, size.width, size.height);
	gl.clearColor(0, 0, 0, 1);
	gl.clear(gl.COLOR_BUFFER_BIT);

	renderer.framebufferSize = za.Vec2.new(@intToFloat(f32, size.width), @intToFloat(f32, size.height));
	switch (game.state) {
		.MainMenu => |*menu| menu.render(&game, &renderer)
	}
}

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
	defer _ = gpa.deinit();
	const allocator = &gpa.allocator;

	try glfw.init();
	defer glfw.deinit();

	var window = try glfw.Window.create();
	try gl.load({}, glfw.getProcAddress);

	renderer = try Renderer.init(allocator, window);
	defer renderer.deinit();
	
	game = Game { .state = .MainMenu };
	window.loop(render);
}

test "basic test" {
	try std.testing.expectEqual(10, 3 + 7);
}
