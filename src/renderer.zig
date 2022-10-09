const std    = @import("std");
const gl     = @import("gl");
const za     = @import("zalgebra");
const zigimg = @import("zigimg");
const nk     = @import("nuklear.zig");
const tracy  = @import("vendor/tracy.zig");
const nvg    = @import("nanovg");
const Window = @import("glfw").Window;
const log    = std.log.scoped(.renderer);

const Allocator = std.mem.Allocator;
const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

pub const Renderer = struct {
	window: Window,
	textureCache: TextureCache,
	vg: nvg,
	vg_vao: gl.GLuint,

	// Shader programs used during the game's lifetime
	terrainProgram: ShaderProgram,
	entityProgram: ShaderProgram,
	skyboxProgram: ShaderProgram,
	sunProgram: ShaderProgram,
	cloudsProgram: ShaderProgram,
	
	/// Shader program used for Nuklear UI
	nuklearProgram: ShaderProgram,

	// Various OpenGL indices
	nuklearVao: gl.GLuint,
	nuklearVbo: gl.GLuint,
	nuklearEbo: gl.GLuint,

	framebufferSize: Vec2,

	// Graphics state for Nuklear
	nkContext: nk.nk_context,
	nkCommands: nk.nk_buffer,
	nkVertices: nk.nk_buffer,
	nkIndices: nk.nk_buffer,
	nkAllocator: *NkAllocator,
	nkFontAtlas: nk.nk_font_atlas,
	tempScroll: nk.struct_nk_vec2 = nk.struct_nk_vec2 { .x = 0, .y = 0 },

	pub fn init(allocator: Allocator, window: Window) !Renderer {
		const zone = tracy.ZoneN(@src(), "Init renderer");
		defer zone.End();
		
		log.debug("  Create shaders", .{});
		const terrainProgram = try ShaderProgram.createFromName("terrain");
		const entityProgram = try ShaderProgram.createFromName("entity");
		const skyboxProgram = try ShaderProgram.createFromName("skybox");
		const sunProgram = try ShaderProgram.createFromName("sun");
		const nuklearProgram = try ShaderProgram.createFromName("nuklear");
		const cloudsProgram = try ShaderProgram.createFromName("clouds");

		log.debug("  Generate Nuklear - OpenGL integration", .{});
		// Generate the VAO, VBO and EBO that will be used for drawing Nuklear UI.
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
		gl.enable(gl.TEXTURE_CUBE_MAP_SEAMLESS);
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

		// Initialise NkAllocator which wraps a Zig allocator as a Nuklear allocator.
		const nkAllocator = try NkAllocator.init(allocator);
		
		log.debug("  Initialize Nuklear", .{});
		var nkCtx: nk.nk_context = undefined;
		if (nk.nk_init(&nkCtx, &nkAllocator.nk, null) == 0) {
			return error.NuklearError;
		}

		log.debug("  Allocate Nuklear commands buffers", .{});
		// At last, initialise the buffers that Nuklear requires for drawing.
		var cmds: nk.nk_buffer = undefined;
		var verts: nk.nk_buffer = undefined;
		var idx: nk.nk_buffer = undefined;
		nk.nk_buffer_init(&cmds, &nkAllocator.nk, 8192);
		nk.nk_buffer_init(&verts, &nkAllocator.nk, 8192);
		nk.nk_buffer_init(&idx, &nkAllocator.nk, 8192);
		log.debug("  Done", .{});

		const vg = try nvg.gl.init(allocator, .{
			.antialias = true,
			.debug = true,
		});
		// generate a VAO for nanovg because it doesn't generate itself for some reason
		var vg_vao: gl.GLuint = 0;
		gl.genVertexArrays(1, &vg_vao);
		
		var file = try std.fs.cwd().openFile("assets/font/Inter.ttf", .{});
		const fontData = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
		vg.fontFaceId(vg.createFontMem("sans-serif", fontData));

		return Renderer {
			.window = window,
			.textureCache = TextureCache.init(allocator),
			.vg = vg,
			.vg_vao = vg_vao,
			.terrainProgram = terrainProgram,
			.entityProgram = entityProgram,
			.skyboxProgram = skyboxProgram,
			.sunProgram = sunProgram,
			.cloudsProgram = cloudsProgram,
			.nuklearProgram = nuklearProgram,
			.nuklearVao = nkVao,
			.nuklearVbo = nkVbo,
			.nuklearEbo = nkEbo,
			.framebufferSize = undefined,
			.nkContext = nkCtx,
			.nkCommands = cmds,
			.nkVertices = verts,
			.nkIndices = idx,
			.nkAllocator = nkAllocator,
			.nkFontAtlas = undefined,
		};
	}

	pub fn reloadShaders(self: *Renderer) !void {
		const terrainProgram = try ShaderProgram.loadFromPath("src/shaders/terrain");
		const entityProgram = try ShaderProgram.loadFromPath("src/shaders/entity");
		const skyboxProgram = try ShaderProgram.loadFromPath("src/shaders/skybox");
		const sunProgram = try ShaderProgram.loadFromPath("src/shaders/sun");
		const cloudsProgram = try ShaderProgram.loadFromPath("src/shaders/clouds");

		self.terrainProgram = terrainProgram;
		self.entityProgram = entityProgram;
		self.skyboxProgram = skyboxProgram;
		self.sunProgram = sunProgram;
		self.cloudsProgram = cloudsProgram;

		log.debug("Reloaded shaders.", .{});
	}

	pub fn onScroll(self: *Renderer, xOffset: f32, yOffset: f32) void {
		self.tempScroll.x += xOffset;
		self.tempScroll.y += yOffset;
	}

	/// This must be called before drawing with NanoVG.
	pub fn startUI(self: *Renderer) void {
		gl.bindVertexArray(self.vg_vao);
		self.vg.beginFrame(
			self.framebufferSize.x(),
			self.framebufferSize.y(),
			1.0 // TODO: get device pixel ratio
		);
	}

	/// Must be called when you are done drawing with NanoVG. This function
	/// handles actually rendering to the screen with OpenGL.
	pub fn endUI(self: *Renderer) void {
		self.vg.endFrame();
		gl.enable(gl.DEPTH_TEST);
	}

	pub fn deinit(self: *Renderer) void {
		self.textureCache.deinit();
		self.vg.deinit();

		nk.nk_buffer_free(&self.nkCommands);
		nk.nk_buffer_free(&self.nkVertices);
		nk.nk_buffer_free(&self.nkIndices);
		nk.nk_free(&self.nkContext);
		self.nkAllocator.deinit();
	}
};

pub const Texture = struct {
	texture: gl.GLuint,

	const PixelFormat = enum(gl.GLenum) {
		RGBA32 = gl.RGBA,
		RGB24 = gl.RGB,
	};

	pub fn loadImage(allocator: Allocator, path: []const u8) !zigimg.Image {
		const zone = tracy.ZoneN(@src(), "Load texture");
		defer zone.End();
		zone.Text(path);

		var file = try std.fs.cwd().openFile(path, .{});
		defer file.close();

		// Manually only allow loading PNG files for faster compilation and lower executable size
		//var image = try zigimg.Image.fromFile(allocator, &file);
		var streamSource = std.io.StreamSource{ .file = file };
		const image = try zigimg.png.PNG.formatInterface().readImage(allocator, &streamSource);
		return image;
	}

	pub fn createFromPath(allocator: Allocator, path: []const u8) !Texture {
		var image = try loadImage(allocator, path);
		defer image.deinit();
		const pixels = &image.pixels;
		var pixelFormat = PixelFormat.RGBA32;
		const data = blk: {
			if (pixels.* == .rgba32) {
				const first = @ptrCast([*]u8, &pixels.rgba32[0]);
				break :blk first[0..image.width*image.height*4];
			} else {
				const first = @ptrCast([*]u8, &pixels.rgb24[0]);
				pixelFormat = .RGB24;
				break :blk first[0..image.width*image.height*3];
			}
		};

		return createFromData(image.width, image.height, data, pixelFormat);
	}

	pub fn createFromData(width: usize, height: usize, data: []const u8, pixelFormat: PixelFormat) Texture {
		const zone = tracy.ZoneN(@src(), "Upload RGBA texture");
		defer zone.End();

		var texture: gl.GLuint = undefined;
		gl.genTextures(1, &texture);
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texImage2D(gl.TEXTURE_2D, 0, @intCast(gl.GLint, @enumToInt(pixelFormat)), 
			@intCast(c_int, width), @intCast(c_int, height), 0, @enumToInt(pixelFormat), gl.UNSIGNED_BYTE, data.ptr);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

		return Texture { .texture = texture };
	}

	pub fn initCubemap() Texture {
		var texture: gl.GLuint = undefined;
		gl.genTextures(1, &texture);
		gl.bindTexture(gl.TEXTURE_CUBE_MAP, texture);
		gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.MIRRORED_REPEAT);
		gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
		gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.MIRRORED_REPEAT);
		gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		return Texture { .texture = texture };
	}

	pub fn generateMipmaps(self: Texture) void {
		gl.bindTexture(gl.TEXTURE_2D, self.texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR_MIPMAP_LINEAR);
		gl.generateMipmap(gl.TEXTURE_2D);
	}

	pub const CubemapFace = enum(gl.GLenum) {
		PositiveX = gl.TEXTURE_CUBE_MAP_POSITIVE_X,
		NegativeX,
		PositiveY,
		NegativeY,
		PositiveZ,
		NegativeZ,
	};

	/// Assumes RGB24
	pub fn setCubemapFace(self: Texture, face: CubemapFace, width: usize, height: usize, data: []const u8) void {
		gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.texture);
		gl.texImage2D(@enumToInt(face), 0, gl.RGB, 
			@intCast(c_int, width), @intCast(c_int, height), 0, gl.RGB, gl.UNSIGNED_BYTE, data.ptr);

	}

	/// Assumes RGB24
	pub fn loadCubemapFace(self: Texture, allocator: Allocator, face: CubemapFace, path: []const u8) !void {
		var image = try loadImage(allocator, path);
		defer image.deinit();
		const first = @ptrCast([*]u8, &image.pixels.rgb24[0]);
		const pixels = first[0..image.width*image.height*3];

		self.setCubemapFace(face, image.width, image.height, pixels);
	}

	pub fn toNkImage(self: Texture) nk.struct_nk_image {
		return .{
			.handle = .{ .id = @intCast(c_int, self.texture) },
			.w = 0, .h = 0,
			.region = .{ 0, 0, 0, 0 }
		};
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
		return getExt(self, name, .{});
	}

	pub const TextureOptions = struct {
		mipmaps: bool = false,
	};

	pub fn getExt(self: *TextureCache, name: []const u8, options: TextureOptions) Texture {
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
			if (options.mipmaps) {
				texture.generateMipmaps();
			}
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

  pub fn loadFromPath(comptime path: []const u8) !ShaderProgram {
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	const vertexShader = Shader.create(gl.VERTEX_SHADER);
		defer vertexShader.deinit();

	const vertexFile = try std.fs.cwd().openFile(path ++ ".vs", .{});
	defer vertexFile.close();

		vertexShader.setSource(try allocator.dupeZ(
	  u8, try vertexFile.readToEndAlloc(allocator, std.math.maxInt(usize))
	));
		try vertexShader.compile();

		const fragmentShader = Shader.create(gl.FRAGMENT_SHADER);
		defer fragmentShader.deinit();

	const fragmentFile = try std.fs.cwd().openFile(path ++ ".fs", .{});
	defer fragmentFile.close();

	fragmentShader.setSource(try allocator.dupeZ(
	  u8, try fragmentFile.readToEndAlloc(allocator, std.math.maxInt(usize))
	));
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

	pub fn setUniformFloat(self: ShaderProgram, uniform: [:0]const u8, float: f32) void {
		const location = gl.getUniformLocation(self.program, uniform);
		gl.uniform1f(location, float);
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

	fn nkAlloc(userdata: nk.nk_handle, old: ?*anyopaque, nsize: nk.nk_size) callconv(.C) ?*anyopaque {
		const self = @ptrCast(*NkAllocator, @alignCast(@alignOf(NkAllocator), userdata.ptr));
		const allocator = self.allocationSizes.allocator;
		_ = old; // old isn't used to realloc as old memory is still expected to work
		const ptr = (allocator.alloc(u8, nsize) catch return null).ptr;
		self.allocationSizes.put(ptr, nsize) catch return null;
		return ptr;
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
