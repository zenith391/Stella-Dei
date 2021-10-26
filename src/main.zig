const std  = @import("std");
const gl   = @import("gl");
const glfw = @import("glfw.zig");

fn render(window: glfw.Window) void {
	const size = window.getFramebufferSize();
	gl.viewport(0, 0, size.width, size.height);

	gl.clearColor(0, 0, 0, 1);
	gl.clear(gl.COLOR_BUFFER_BIT);
}

pub fn main() !void {
	try glfw.init();
	defer glfw.deinit();

	var window = try glfw.Window.create();
	try gl.load({}, glfw.getProcAddress);

	window.loop(render);
}

test "basic test" {
	try std.testing.expectEqual(10, 3 + 7);
}
