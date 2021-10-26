const std = @import("std");
const glfw = @import("glfw.zig");

fn render() void {

}

pub fn main() !void {
	try glfw.init();
	defer glfw.deinit();

	var window = try glfw.Window.create();
	window.loop(render);
}

test "basic test" {
	try std.testing.expectEqual(10, 3 + 7);
}
