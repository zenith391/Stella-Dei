const c = @import("glfw-c.zig");

pub fn init() !void {
	if (c.glfwInit() == 0) {
		return error.InitializationError;
	}
}

pub fn deinit() void {
	c.glfwTerminate();
}

pub const Window = struct {
	window: *c.GLFWwindow,

	pub fn create() !Window {
		var window = c.glfwCreateWindow(640, 480, "", null, null) orelse return error.GlfwError;
		c.glfwMakeContextCurrent(window);

		return Window {
			.window = window
		};
	}

	/// Make the event loop and use the given function for rendering
	pub fn loop(self: Window, render: anytype) void {
		while (!self.shouldClose()) {
			render();

			c.glfwSwapBuffers(self.window);
			c.glfwPollEvents();
		}
	}

	pub fn shouldClose(self: Window) bool {
		return c.glfwWindowShouldClose(self.window) != 0;
	}

};

