const std    = @import("std");
const gl     = @import("gl");
const za     = @import("zalgebra");
const Window = @import("glfw.zig").Window;
const log    = std.log.scoped(.renderer);

const Allocator = std.mem.Allocator;
const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

/// Vertices that compose a quad, it will often be used so here is it
const quadVertices = [_]f32 {
	-0.5, -0.5,
	-0.5,  0.5,
	 0.5,  0.5,
	 0.5,  0.5,
	 0.5, -0.5,
	-0.5, -0.5,
};

pub const Renderer = struct {
	window: *Window,
	textureCache: TextureCache,

	colorProgram: ShaderProgram,
	imageProgram: ShaderProgram,
	terrainProgram: ShaderProgram,
	quadVao: gl.GLuint,
	framebufferSize: Vec2,

	// Graphics state
	color: Vec3 = Vec3.one(),

	pub fn init(allocator: *Allocator, window: *Window) !Renderer {
		const colorProgram = try ShaderProgram.createFromName("color");
		const imageProgram = try ShaderProgram.createFromName("image");
		const terrainProgram = try ShaderProgram.createFromName("terrain");

		var vao: gl.GLuint = undefined;
		gl.genVertexArrays(1, &vao);
		var vbo: gl.GLuint = undefined;
		gl.genBuffers(1, &vbo);

		gl.bindVertexArray(vao);
		gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
		gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(quadVertices)), &quadVertices, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), null);
		gl.enableVertexAttribArray(0);

		// TODO: disable depth test in 2D (it causes blending problems)
		gl.enable(gl.DEPTH_TEST);
		gl.enable(gl.BLEND);
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

		colorProgram.use();
		colorProgram.setUniformMat4("projMatrix",
			Mat4.orthographic(0, 1, 1, 0, 0, 10));
		imageProgram.use();
		imageProgram.setUniformMat4("projMatrix",
			Mat4.orthographic(0, 1, 1, 0, 0, 10));

		return Renderer {
			.window = window,
			.textureCache = TextureCache.init(allocator),
			.colorProgram = colorProgram,
			.imageProgram = imageProgram,
			.terrainProgram = terrainProgram,
			.quadVao = vao,
			.framebufferSize = undefined
		};
	}

	pub fn setColor(self: *Renderer, color: Vec3) void {
		self.color = color;
	}

	fn getModelMatrix(x: f32, y: f32, w: f32, h: f32, rot: f32) Mat4 {
		const translate = Vec3.new(x + w / 2, y + h / 2, 0);
		const scale = Vec3.new(w, h, 1);

		return Mat4.recompose(translate, Vec3.new(0, 0, rot), scale);
	}

	pub fn fillRect(self: *Renderer, x: f32, y: f32, w: f32, h: f32, rot: f32) void {
		self.colorProgram.use();
		self.colorProgram.setUniformVec3("color", self.color);
		self.colorProgram.setUniformMat4("projMatrix",
			Mat4.orthographic(0, self.framebufferSize.x, self.framebufferSize.y, 0, 0, 10));
		self.colorProgram.setUniformMat4("modelMatrix",
			getModelMatrix(x, y, w, h, rot));

		gl.bindVertexArray(self.quadVao);
		gl.drawArrays(gl.TRIANGLES, 0, 6);
	}

	pub fn drawTextureObject(self: *Renderer, texture: Texture, x: f32, y: f32, w: f32, h: f32, rot: f32) void {
		self.imageProgram.use();
		self.imageProgram.setUniformInt("uTexture", 0);
		self.imageProgram.setUniformMat4("projMatrix",
			Mat4.orthographic(0, self.framebufferSize.x, self.framebufferSize.y, 0, 0, 10));
		self.imageProgram.setUniformMat4("modelMatrix",
			getModelMatrix(x, y, w, h, rot));

		gl.bindTexture(gl.TEXTURE_2D, texture.texture);
		gl.bindVertexArray(self.quadVao);
		gl.drawArrays(gl.TRIANGLES, 0, 6);
	}

	pub fn drawTexture(self: *Renderer, name: []const u8, x: f32, y: f32, w: f32, h: f32, rot: f32) void {
		self.drawTextureObject(
			self.textureCache.get(name),
			x, y, w, h, rot
		);
	}

	pub fn deinit(self: *Renderer) void {
		self.textureCache.deinit();
	}
};

const zigimg = @import("zigimg");

pub const Texture = struct {
	texture: gl.GLuint,

	pub fn createFromPath(allocator: *Allocator, path: []const u8) !Texture {
		var file = try std.fs.cwd().openFile(path, .{});
		defer file.close();

		var image = try zigimg.Image.fromFile(allocator, &file);
		defer image.deinit();

		const first = @ptrCast([*]u8, &image.pixels.?.Rgba32[0]);
		const pixels = first[0..image.width*image.height*4];

		return createFromData(image.width, image.height, pixels);
	}

	pub fn createFromData(width: usize, height: usize, data: []const u8) Texture {
		var texture: gl.GLuint = undefined;
		gl.genTextures(1, &texture);
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 
			@intCast(c_int, width), @intCast(c_int, height), 0, gl.RGBA, gl.UNSIGNED_BYTE, data.ptr);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);

		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.generateMipmap(gl.TEXTURE_2D);

		return Texture { .texture = texture };
	}
};

pub const TextureCache = struct {
	cache: std.StringHashMap(Texture),

	pub fn init(allocator: *Allocator) TextureCache {
		return TextureCache {
			.cache = std.StringHashMap(Texture).init(allocator)
		};
	}

	pub fn get(self: *TextureCache, name: []const u8) Texture {
		if (self.cache.get(name)) |texture| {
			return texture;
		} else {
			const path = std.mem.concat(self.cache.allocator, u8,
				&[_][]const u8 { "assets/", name, ".png" }) catch unreachable;
			defer self.cache.allocator.free(path);

			const texture = Texture.createFromPath(self.cache.allocator, path) catch |err| {
				std.log.warn("could not load texture at '{s}': {s}", .{ path, @errorName(err) });
				if (@errorReturnTrace()) |trace| {
					std.debug.dumpStackTrace(trace.*);
				}
				@panic("TODO: placeholder texture");
			};
			self.cache.put(name, texture) catch unreachable;

			return texture;
		}
	}

	pub fn deinit(self: *TextureCache) void {
		self.cache.deinit();
	}
};

const Shader = struct {
	shader: gl.GLuint,

	pub fn create(kind: gl.GLenum) Shader {
		return Shader {
			.shader = gl.createShader(kind)
		};
	}

	pub fn setSource(self: Shader, source: [:0]const u8) void {
		gl.shaderSource(self.shader, 1, &[_][*c]const u8 { source.ptr }, null);
	}

	pub fn compile(self: Shader) !void {
		gl.compileShader(self.shader);

		var successful: c_int = undefined;
		gl.getShaderiv(self.shader, gl.COMPILE_STATUS, &successful);
		if (successful != gl.TRUE) {
			var infoLogLen: c_int = undefined;
			gl.getShaderiv(self.shader, gl.INFO_LOG_LENGTH, &infoLogLen);

			const allocator = std.heap.page_allocator; // it's for an error case so
			const infoLog = allocator.allocSentinel(u8, @intCast(usize, infoLogLen), 0) catch {
				log.err("Could not get info log: out of memory", .{});
				return error.CompileError;
			};
			defer allocator.free(infoLog);

			gl.getShaderInfoLog(self.shader, infoLogLen, null, infoLog.ptr);
			log.err("shader compile error: {s}", .{ infoLog });

			return error.CompileError;
		}
	}

	pub fn deinit(self: Shader) void {
		gl.deleteShader(self.shader);
	}
};

const ShaderProgram = struct {
	program: gl.GLuint,

	pub fn create() ShaderProgram {
		return ShaderProgram {
			.program = gl.createProgram()
		};
	}

	/// Creates a linked ready to use shader program
	pub fn createFromName(comptime name: []const u8) !ShaderProgram {
		const vertexShader = Shader.create(gl.VERTEX_SHADER);
		defer vertexShader.deinit();

		vertexShader.setSource(@embedFile("shaders/" ++ name ++ ".vs"));
		try vertexShader.compile();

		const fragmentShader = Shader.create(gl.FRAGMENT_SHADER);
		defer fragmentShader.deinit();

		fragmentShader.setSource(@embedFile("shaders/" ++ name ++ ".fs"));
		try fragmentShader.compile();

		var program = ShaderProgram.create();
		program.attach(fragmentShader);
		program.attach(vertexShader);
		try program.link();

		return program;
	}

	pub fn setUniformVec2(self: ShaderProgram, uniform: [:0]const u8, vec: Vec2) void {
		const location = gl.getUniformLocation(self.program, uniform);
		gl.uniform2f(location, vec.x, vec.y);
	}

	pub fn setUniformVec3(self: ShaderProgram, uniform: [:0]const u8, vec: Vec3) void {
		const location = gl.getUniformLocation(self.program, uniform);
		gl.uniform3f(location, vec.x, vec.y, vec.z);
	}

	pub fn setUniformMat4(self: ShaderProgram, uniform: [:0]const u8, mat: Mat4) void {
		const location = gl.getUniformLocation(self.program, uniform);
		gl.uniformMatrix4fv(location, 1, gl.FALSE, mat.getData());
	}

	pub fn setUniformInt(self: ShaderProgram, uniform: [:0]const u8, int: c_int) void {
		const location = gl.getUniformLocation(self.program, uniform);
		gl.uniform1i(location, int);
	}

	pub fn attach(self: ShaderProgram, shader: Shader) void {
		gl.attachShader(self.program, shader.shader);
	}

	pub fn link(self: ShaderProgram) !void {
		gl.linkProgram(self.program);
		// TODO: check for errors
	}

	pub fn use(self: ShaderProgram) void {
		gl.useProgram(self.program);
	}

};