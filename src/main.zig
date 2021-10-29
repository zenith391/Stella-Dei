const std  = @import("std");
const gl   = @import("gl");
const glfw = @import("glfw.zig");

const Renderer = @import("renderer.zig").Renderer;
const Texture = @import("renderer.zig").Texture;

var renderer: Renderer = undefined;
var texture: Texture = undefined;

fn render(window: glfw.Window) void {
	const size = window.getFramebufferSize();
	gl.viewport(0, 0, size.width, size.height);
	gl.clearColor(0, 0, 0, 1);
	gl.clear(gl.COLOR_BUFFER_BIT);

	renderer.fillRect(0, 0, 100, 100);
	renderer.fillRect(100, 100, 100, 100);
	renderer.drawTexture(texture, 200, 200, 250, 250);
}

pub fn main() !void {
	try glfw.init();
	defer glfw.deinit();

	var window = try glfw.Window.create();
	try gl.load({}, glfw.getProcAddress);

	renderer = Renderer { .window = window };
	try renderer.init();
	texture = try Texture.createFromPath(std.heap.page_allocator, "sun.png");
	window.loop(render);
}

test "basic test" {
	try std.testing.expectEqual(10, 3 + 7);
}
