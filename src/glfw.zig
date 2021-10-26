const c = @import("glfw-c.zig");

pub fn init() !void {
	if (c.glfwInit() == 0) {
		return error.InitializationError;
	}
}

pub fn deinit() void {
	c.glfwTerminate();
}

/// This is used by zig-opengl library to load OpenGL functions from GLFW
pub fn getProcAddress(_: void, name: [:0]const u8) ?*c_void {
    var proc = c.glfwGetProcAddress(name);
    return @intToPtr(?*c_void, @ptrToInt(proc));
}

pub const Size = struct {
	width: c_int,
	height: c_int
};

pub const Window = struct {
	window: *c.GLFWwindow,

	pub fn create() !Window {
		var window = c.glfwCreateWindow(640, 480, "", null, null) orelse return error.GlfwError;
		c.glfwMakeContextCurrent(window);

		return Window {
			.window = window
		};
	}

	pub fn getSize(self: Window) Size {
		var width: c_int  = undefined;
		var height: c_int = undefined;
		c.glfwGetWindowSize(self.window, &width, &height);

		return Size { .width = width, .height = height };
	}

	pub fn getFramebufferSize(self: Window) Size {
		var width: c_int  = undefined;
		var height: c_int = undefined;
		c.glfwGetFramebufferSize(self.window, &width, &height);

		return Size { .width = width, .height = height };
	}

	/// Make the event loop and use the given function for rendering
	pub fn loop(self: Window, render: anytype) void {
		while (!self.shouldClose()) {
			c.glfwMakeContextCurrent(self.window);
			render(self);

			c.glfwSwapBuffers(self.window);
			c.glfwPollEvents();
		}
	}

	pub fn shouldClose(self: Window) bool {
		return c.glfwWindowShouldClose(self.window) != 0;
	}

};

