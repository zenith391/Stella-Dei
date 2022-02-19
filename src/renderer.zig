const std    = @import("std");
const gl     = @import("gl");
const za     = @import("zalgebra");
const zigimg = @import("zigimg");
const nk     = @import("nuklear.zig");
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
	/// Shader program used for Nuklear UI
	nuklearProgram: ShaderProgram,
	quadVao: gl.GLuint,
	nuklearVao: gl.GLuint,
	nuklearVbo: gl.GLuint,
	nuklearEbo: gl.GLuint,
	framebufferSize: Vec2,

	// Graphics state
	color: Vec3 = Vec3.one(),
	nkContext: nk.nk_context,
	nkCommands: nk.nk_buffer,
	nkVertices: nk.nk_buffer,
	nkIndices: nk.nk_buffer,
	nkAllocator: *NkAllocator,
	nkFontAtlas: nk.nk_font_atlas,

	pub fn init(allocator: Allocator, window: *Window) !Renderer {
		const colorProgram = try ShaderProgram.createFromName("color");
		const imageProgram = try ShaderProgram.createFromName("image");
		const terrainProgram = try ShaderProgram.createFromName("terrain");
		const nuklearProgram = try ShaderProgram.createFromName("nuklear");

		var vao: gl.GLuint = undefined;
		gl.genVertexArrays(1, &vao);
		var vbo: gl.GLuint = undefined;
		gl.genBuffers(1, &vbo);

		gl.bindVertexArray(vao);
		gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
		gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(quadVertices)), &quadVertices, gl.STATIC_DRAW);
		gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), null);
		gl.enableVertexAttribArray(0);

		var nkVao: gl.GLuint = undefined;
		gl.genVertexArrays(1, &nkVao);
		var nkVbo: gl.GLuint = undefined;
		gl.genBuffers(1, &nkVbo);
		var nkEbo: gl.GLuint = undefined;
		gl.genBuffers(1, &nkEbo);

		gl.bindVertexArray(nkVao);
		gl.bindBuffer(gl.ARRAY_BUFFER, nkVbo);
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, nkVbo);
		gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, 0 * @sizeOf(f32)));
		gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, 2 * @sizeOf(f32)));
		gl.vertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, 4 * @sizeOf(f32)));
		gl.enableVertexAttribArray(0);
		gl.enableVertexAttribArray(1);
		gl.enableVertexAttribArray(2);

		// TODO: disable depth test in 2D (it causes blending problems)
		gl.enable(gl.DEPTH_TEST);
		gl.enable(gl.BLEND);
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

		const nkAllocator = try NkAllocator.init(allocator);

		var fontAtlas: nk.nk_font_atlas = undefined;
		nk.nk_font_atlas_init(&fontAtlas, &nkAllocator.nk);
		nk.nk_font_atlas_begin(&fontAtlas);
		var fontConfig = nk.nk_font_config(16.0);
		fontConfig.oversample_h = 6;
		fontConfig.oversample_v = 6;

		const font: *nk.nk_font = nk.nk_font_atlas_add_default(&fontAtlas, 16.0, &fontConfig).?;

		var imgWidth: c_int = undefined;
		var imgHeight: c_int = undefined;
		
		const img = @ptrCast([*]const u8, nk.nk_font_atlas_bake(&fontAtlas, &imgWidth, &imgHeight, nk.NK_FONT_ATLAS_RGBA32).?);
		const atlasTex = Texture.createFromData(@intCast(usize, imgWidth), @intCast(usize, imgHeight),
			img[0..@intCast(usize, imgWidth*imgHeight)]);
		nk.nk_font_atlas_end(&fontAtlas, nk.nk_handle_id(@intCast(c_int, atlasTex.texture)), 0);
		
		var nkCtx: nk.nk_context = undefined;
		if (nk.nk_init(&nkCtx, &nkAllocator.nk, &font.handle) == 0) {
			return error.NuklearError;
		}

		var cmds: nk.nk_buffer = undefined;
		var verts: nk.nk_buffer = undefined;
		var idx: nk.nk_buffer = undefined;
		nk.nk_buffer_init(&cmds, &nkAllocator.nk, 8192);
		nk.nk_buffer_init(&verts, &nkAllocator.nk, 8192*2);
		nk.nk_buffer_init(&idx, &nkAllocator.nk, 8192);

		return Renderer {
			.window = window,
			.textureCache = TextureCache.init(allocator),
			.colorProgram = colorProgram,
			.imageProgram = imageProgram,
			.terrainProgram = terrainProgram,
			.nuklearProgram = nuklearProgram,
			.quadVao = vao,
			.nuklearVao = nkVao,
			.nuklearVbo = nkVbo,
			.nuklearEbo = nkEbo,
			.framebufferSize = undefined,
			.nkContext = nkCtx,
			.nkCommands = cmds,
			.nkVertices = verts,
			.nkIndices = idx,
			.nkAllocator = nkAllocator,
			.nkFontAtlas = fontAtlas,
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
			Mat4.orthographic(0, self.framebufferSize.x(), self.framebufferSize.y(), 0, 0, 10));
		self.colorProgram.setUniformMat4("modelMatrix",
			getModelMatrix(x, y, w, h, rot));

		gl.bindVertexArray(self.quadVao);
		gl.drawArrays(gl.TRIANGLES, 0, 6);
	}

	pub fn drawTextureObject(self: *Renderer, texture: Texture, x: f32, y: f32, w: f32, h: f32, rot: f32) void {
		self.imageProgram.use();
		self.imageProgram.setUniformInt("uTexture", 0);
		self.imageProgram.setUniformMat4("projMatrix",
			Mat4.orthographic(0, self.framebufferSize.x(), self.framebufferSize.y(), 0, 0, 10));
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

	pub fn startUI(self: *Renderer) void {
		nk.nk_input_begin(&self.nkContext);

		const cursorPos = self.window.getCursorPos();
		nk.nk_input_motion(&self.nkContext,
			@floatToInt(c_int, cursorPos.x()), @floatToInt(c_int, cursorPos.y()));
		nk.nk_input_button(&self.nkContext, nk.NK_BUTTON_LEFT, @floatToInt(c_int, cursorPos.x()),
			@floatToInt(c_int, cursorPos.y()), if (self.window.isMousePressed(.Left)) 1 else 0);

		nk.nk_input_end(&self.nkContext);
	}

	pub fn endUI(self: *Renderer) void {
		const vertexLayout = [_]nk.nk_draw_vertex_layout_element {
			.{ .attribute = nk.NK_VERTEX_POSITION, .format = nk.NK_FORMAT_FLOAT, .offset = 0 },
			.{ .attribute = nk.NK_VERTEX_TEXCOORD, .format = nk.NK_FORMAT_FLOAT, .offset = 8 },
			.{ .attribute = nk.NK_VERTEX_COLOR, .format = nk.NK_FORMAT_R32G32B32A32_FLOAT, .offset = 16 },
			// end of vertex layout
			.{ .attribute = nk.NK_VERTEX_ATTRIBUTE_COUNT, .format = nk.NK_FORMAT_COUNT, .offset = 0 },
		};

		const convertConfig = nk.nk_convert_config {
			.global_alpha = 1.0,
			.line_AA = nk.NK_ANTI_ALIASING_ON,
			.shape_AA = nk.NK_ANTI_ALIASING_ON,
			.vertex_layout = &vertexLayout,
			.vertex_size = 8 * @sizeOf(f32),
			.vertex_alignment = @alignOf(f32),
			.circle_segment_count = 22,
			.curve_segment_count = 22,
			.arc_segment_count = 22,
			.@"null" = .{
				.texture = .{ .id = 0 },
				.uv = .{ .x = 0, .y = 0 }
			},
		};

		if (nk.nk_convert(&self.nkContext, &self.nkCommands, &self.nkVertices, &self.nkIndices, &convertConfig) != 0) {
			std.log.warn("nk_convert error", .{});
		}

		gl.disable(gl.DEPTH_TEST);
		defer gl.enable(gl.DEPTH_TEST);
		gl.enable(gl.SCISSOR_TEST);
		defer gl.disable(gl.SCISSOR_TEST);

		gl.enable(gl.BLEND);
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

		self.nuklearProgram.use();
		self.nuklearProgram.setUniformMat4("projMatrix",
			Mat4.orthographic(0, self.framebufferSize.x(), self.framebufferSize.y(), 0, 0, 10));

		gl.bindVertexArray(self.nuklearVao);
		gl.bindBuffer(gl.ARRAY_BUFFER, self.nuklearVbo);
		gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, nk.nk_buffer_total(&self.nkVertices)),
			nk.nk_buffer_memory_const(&self.nkVertices), gl.STREAM_DRAW);
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.nuklearEbo);
		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(isize, nk.nk_buffer_total(&self.nkIndices)),
			nk.nk_buffer_memory_const(&self.nkIndices), gl.STREAM_DRAW);
		gl.activeTexture(gl.TEXTURE0);
		self.nuklearProgram.setUniformInt("uTexture", 0);

		var command = nk.nk__draw_begin(&self.nkContext, &self.nkCommands);
		var offset: usize = 0;
		while (command) |cmd| {
			if (cmd.*.elem_count > 0) {
				self.nuklearProgram.setUniformInt("useTexture", if (cmd.*.texture.id != 0) 1 else 0); // not null texture
				gl.bindTexture(gl.TEXTURE_2D, @intCast(gl.GLuint, cmd.*.texture.id));
				const clip = cmd.*.clip_rect;
				gl.scissor(
					@floatToInt(gl.GLint, clip.x),
					@floatToInt(gl.GLint, self.framebufferSize.y() - (clip.y + clip.h)),
					@floatToInt(gl.GLint, clip.w),
					@floatToInt(gl.GLint, clip.h),
				);
				gl.drawElements(gl.TRIANGLES, @intCast(gl.GLint, cmd.*.elem_count), gl.UNSIGNED_SHORT, 
					@intToPtr(?*anyopaque, offset * 2));
			}
			offset += cmd.*.elem_count;
			command = nk.nk__draw_next(cmd, &self.nkCommands, &self.nkContext);
		}

		nk.nk_clear(&self.nkContext);
		nk.nk_buffer_clear(&self.nkCommands);
		nk.nk_buffer_clear(&self.nkVertices);
		nk.nk_buffer_clear(&self.nkIndices);
	}

	pub fn deinit(self: *Renderer) void {
		self.textureCache.deinit();

		nk.nk_buffer_free(&self.nkCommands);
		nk.nk_buffer_free(&self.nkVertices);
		nk.nk_buffer_free(&self.nkIndices);
		nk.nk_font_atlas_clear(&self.nkFontAtlas);
		nk.nk_free(&self.nkContext);
		self.nkAllocator.deinit();
	}
};

pub const Texture = struct {
	texture: gl.GLuint,

	pub fn createFromPath(allocator: Allocator, path: []const u8) !Texture {
		var file = try std.fs.cwd().openFile(path, .{});
		defer file.close();

		// Manually only allow loading PNG files for faster compilation and lower executable size
		//var image = try zigimg.Image.fromFile(allocator, &file);
		var image = zigimg.Image.init(allocator);
		defer image.deinit();
		var streamSource = std.io.StreamSource{ .file = file };
		const imageInfo = try zigimg.png.PNG.formatInterface().readForImage(allocator, streamSource.reader(),
			streamSource.seekableStream(), &image.pixels);
		image.width = imageInfo.width;
		image.height = imageInfo.height;

		const first = @ptrCast([*]u8, &image.pixels.?.Rgba32[0]);
		const pixels = first[0..image.width*image.height*4];

		return createFromData(image.width, image.height, pixels);
	}

	/// Assumes RGBA32
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

	pub fn init(allocator: Allocator) TextureCache {
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
		gl.uniform2f(location, vec.x(), vec.y());
	}

	pub fn setUniformVec3(self: ShaderProgram, uniform: [:0]const u8, vec: Vec3) void {
		const location = gl.getUniformLocation(self.program, uniform);
		gl.uniform3f(location, vec.x(), vec.y(), vec.z());
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

/// Utility struct to wrap a std.mem.Allocator as a nk_allocator
const NkAllocator = struct {
	nk: nk.nk_allocator,
	/// As Nuklear doesn't keep track of allocation sizes, we keep the size of each
	/// allocation associated to its pointer.
	allocationSizes: std.AutoHashMap(*anyopaque, usize),

	fn nkAlloc(userdata: nk.nk_handle, old: ?*anyopaque, nsize: usize) callconv(.C) ?*anyopaque {
		const self = @ptrCast(*NkAllocator, @alignCast(@alignOf(NkAllocator), userdata.ptr));
		const allocator = self.allocationSizes.allocator;
		if (old) |old_buf| {
			const size = self.allocationSizes.get(old_buf).?;
			return (allocator.realloc(
				@as([]u8, @ptrCast([*]u8, old_buf)[0..size]), nsize) catch unreachable).ptr;
		} else {
			const ptr = (allocator.alloc(u8, nsize) catch return null).ptr;
			self.allocationSizes.put(ptr, nsize) catch return null;
			return ptr;
		}
	}

	fn nkFree(userdata: nk.nk_handle, old: ?*anyopaque) callconv(.C) void {
		const self = @ptrCast(*NkAllocator, @alignCast(@alignOf(NkAllocator), userdata.ptr)).*;
		const allocator = self.allocationSizes.allocator;
		if (old) |old_buf| {
			const size = self.allocationSizes.get(old_buf).?;
			allocator.free(@as([]u8, @ptrCast([*]u8, old)[0..size]));
		}
	}

	pub fn init(allocator: Allocator) !*NkAllocator {
		const obj = try allocator.create(NkAllocator);
		obj.* = NkAllocator {
			.nk = nk.nk_allocator {
				.userdata = .{ .ptr = obj },
				.alloc = nkAlloc,
				.free = nkFree,
			},
			.allocationSizes = std.AutoHashMap(*anyopaque, usize).init(allocator)
		};
		return obj;
	}

	pub fn deinit(self: *NkAllocator) void {
		const allocator = self.allocationSizes.allocator;
		self.allocationSizes.deinit();
		allocator.destroy(self);
	}

};