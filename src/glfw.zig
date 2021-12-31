const c = @import("glfw-c.zig");
const za = @import("zalgebra");
const std = @import("std");

const Vec2 = za.Vec2;

pub fn init() !void {
	if (c.glfwInit() == 0) {
		return error.InitializationError;
	}

	_ = c.glfwSetErrorCallback(glfwErrorCallback);
}

fn glfwErrorCallback(code: c_int, description: ?[*:0]const u8) callconv(.C) void {
	std.log.err("GLFW error: {s} (code {d})", .{ description.?, code });
}

pub fn deinit() void {
	c.glfwTerminate();
}

/// This is used by zig-opengl library to load OpenGL functions from GLFW
pub fn getProcAddress(_: void, name: [:0]const u8) ?*anyopaque {
	var proc = c.glfwGetProcAddress(name);
	return @intToPtr(?*anyopaque, @ptrToInt(proc));
}

pub const Size = struct {
	width: c_int,
	height: c_int
};

pub const MouseButton = enum(c_int) {
	Left = 0,
	Right = 1,
	Middle = 2,
	_
};

pub const Window = struct {
	window: *c.GLFWwindow,
	mousePressed: ?fn(Window, MouseButton) void = null,
	mouseReleased: ?fn(Window, MouseButton) void = null,

	fn mouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
		_ = mods;
		const self = @ptrCast(*Window, @alignCast(@alignOf(Window), c.glfwGetWindowUserPointer(window)));
		const mouseButton = @intToEnum(MouseButton, button);
		
		if (action == c.GLFW_PRESS) {
			if (self.mousePressed) |mousePressed| {
				mousePressed(self.*, mouseButton);
			}
		} else {
			if (self.mouseReleased) |mouseReleased| {
				mouseReleased(self.*, mouseButton);
			}
		}
	}

	pub fn create() !Window {
		c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
		c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 6);
		c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
		var window = c.glfwCreateWindow(640, 480, "Name Not Included", null, null) orelse return error.GlfwError;
		c.glfwMakeContextCurrent(window);

		return Window {
			.window = window
		};
	}

	/// self is expected to be a pointer that won't change during the window's lifetime
	pub fn initEvents(self: *Window) void {
		c.glfwSetWindowUserPointer(self.window, self);
		_ = c.glfwSetMouseButtonCallback(self.window, mouseButtonCallback);
	}

	pub fn getSize(self: Window) Size {
		var width:  c_int  = undefined;
		var height: c_int  = undefined;
		c.glfwGetWindowSize(self.window, &width, &height);

		return Size { .width = width, .height = height };
	}

	pub fn getFramebufferSize(self: Window) Size {
		var width:  c_int  = undefined;
		var height: c_int  = undefined;
		c.glfwGetFramebufferSize(self.window, &width, &height);

		return Size { .width = width, .height = height };
	}

	pub fn getFramebufferWidth(self: Window) c_int {
		return self.getFramebufferSize().width;
	}

	pub fn getFramebufferHeight(self: Window) c_int {
		return self.getFramebufferSize().height;
	}

	pub fn getCursorPos(self: Window) Vec2 {
		var x: f64 = undefined;
		var y: f64 = undefined;
		c.glfwGetCursorPos(self.window, &x, &y);

		return Vec2.new(@floatCast(f32, x), @floatCast(f32, y));
	}

	pub fn isMousePressed(self: Window, button: MouseButton) bool {
		return c.glfwGetMouseButton(self.window, @enumToInt(button)) == c.GLFW_PRESS;
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

