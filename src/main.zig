const std  = @import("std");
const gl   = @import("gl");
const glfw = @import("glfw.zig");

const Renderer = @import("renderer.zig").Renderer;

var renderer: Renderer = undefined;
var y: u32 = 0;

fn render(window: glfw.Window) void {
	const size = window.getFramebufferSize();
	gl.viewport(0, 0, size.width, size.height);

	gl.clearColor(0, 0, 0, 1);
	gl.clear(gl.COLOR_BUFFER_BIT);
	renderer.fillRect(0, y, 100, 100);
	y += 1;
	if (y > size.height) { y = 0; }
}

pub fn main() !void {
	try glfw.init();
	defer glfw.deinit();

	var window = try glfw.Window.create();
	try gl.load({}, glfw.getProcAddress);

	renderer = Renderer { .window = window };
	try renderer.init();
	window.loop(render);
}

test "basic test" {
	try std.testing.expectEqual(10, 3 + 7);
}
