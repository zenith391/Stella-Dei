const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const zigimg = @import("zigimg");
const tracy = @import("vendor/tracy.zig");
const nvg = @import("nanovg");
const Window = @import("glfw").Window;
const log = std.log.scoped(.renderer);

const Allocator = std.mem.Allocator;
const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

pub const Renderer = struct {
    window: Window,
    textureCache: TextureCache,
    vg: nvg,
    vg_vao: gl.GLuint,
    quad_vao: gl.GLuint,

    // Shader programs used during the game's lifetime
    terrainProgram: ShaderProgram,
    entityProgram: ShaderProgram,
    skyboxProgram: ShaderProgram,
    sunProgram: ShaderProgram,
    cloudsProgram: ShaderProgram,
    postprocessProgram: ShaderProgram,

    framebufferSize: Vec2,

    pub fn init(allocator: Allocator, window: Window) !Renderer {
        const zone = tracy.ZoneN(@src(), "Init renderer");
        defer zone.End();

        log.debug("  Create shaders", .{});
        const terrainProgram = try ShaderProgram.createFromName("terrain");
        const entityProgram = try ShaderProgram.createFromName("entity");
        const skyboxProgram = try ShaderProgram.createFromName("skybox");
        const sunProgram = try ShaderProgram.createFromName("sun");
        const cloudsProgram = try ShaderProgram.createFromName("clouds");
        const postprocessProgram = try ShaderProgram.createFromName("postprocess");

        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.BLEND);
        gl.enable(gl.TEXTURE_CUBE_MAP_SEAMLESS);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

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

        var quad_vao: gl.GLuint = 0;
        gl.genVertexArrays(1, &quad_vao);

        return Renderer{
            .window = window,
            .textureCache = TextureCache.init(allocator),
            .vg = vg,
            .vg_vao = vg_vao,
            .quad_vao = quad_vao,
            .terrainProgram = terrainProgram,
            .entityProgram = entityProgram,
            .skyboxProgram = skyboxProgram,
            .sunProgram = sunProgram,
            .cloudsProgram = cloudsProgram,
            .postprocessProgram = postprocessProgram,
            .framebufferSize = undefined,
        };
    }

    pub fn reloadShaders(self: *Renderer) !void {
        const terrainProgram = try ShaderProgram.loadFromPath("src/shaders/terrain");
        const entityProgram = try ShaderProgram.loadFromPath("src/shaders/entity");
        const skyboxProgram = try ShaderProgram.loadFromPath("src/shaders/skybox");
        const sunProgram = try ShaderProgram.loadFromPath("src/shaders/sun");
        const cloudsProgram = try ShaderProgram.loadFromPath("src/shaders/clouds");
        const postprocessProgram = try ShaderProgram.loadFromPath("src/shaders/postprocess");

        self.terrainProgram = terrainProgram;
        self.entityProgram = entityProgram;
        self.skyboxProgram = skyboxProgram;
        self.sunProgram = sunProgram;
        self.cloudsProgram = cloudsProgram;
        self.postprocessProgram = postprocessProgram;

        log.debug("Reloaded shaders.", .{});
    }

    /// This must be called before drawing with NanoVG.
    pub fn startUI(self: *Renderer) void {
        gl.bindVertexArray(self.vg_vao);
        self.vg.beginFrame(self.framebufferSize.x(), self.framebufferSize.y(), 1.0 // TODO: get device pixel ratio
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
    }
};

pub const Texture = struct {
    texture: gl.GLuint,
    nvgHandle: ?i32 = null,
    width: usize,
    height: usize,

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
        const managed_image = image.toManaged(allocator);
        return managed_image;
    }

    pub fn createFromPath(allocator: Allocator, path: []const u8) !Texture {
        var image = try loadImage(allocator, path);
        defer image.deinit();
        const pixels = &image.pixels;
        var pixelFormat = PixelFormat.RGBA32;
        const data = blk: {
            if (pixels.* == .rgba32) {
                const first = @as([*]u8, @ptrCast(&pixels.rgba32[0]));
                break :blk first[0 .. image.width * image.height * 4];
            } else {
                const first = @as([*]u8, @ptrCast(&pixels.rgb24[0]));
                pixelFormat = .RGB24;
                break :blk first[0 .. image.width * image.height * 3];
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
        gl.texImage2D(gl.TEXTURE_2D, 0, @as(gl.GLint, @intCast(@intFromEnum(pixelFormat))), @as(c_int, @intCast(width)), @as(c_int, @intCast(height)), 0, @intFromEnum(pixelFormat), gl.UNSIGNED_BYTE, data.ptr);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        return Texture{ .texture = texture, .width = width, .height = height };
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
        return Texture{ .texture = texture, .width = 1, .height = 1 };
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
        gl.texImage2D(@intFromEnum(face), 0, gl.RGB, @as(c_int, @intCast(width)), @as(c_int, @intCast(height)), 0, gl.RGB, gl.UNSIGNED_BYTE, data.ptr);
    }

    /// Assumes RGB24
    pub fn loadCubemapFace(self: Texture, allocator: Allocator, face: CubemapFace, path: []const u8) !void {
        var image = try loadImage(allocator, path);
        defer image.deinit();
        const first = @as([*]u8, @ptrCast(&image.pixels.rgb24[0]));
        const pixels = first[0 .. image.width * image.height * 3];

        self.setCubemapFace(face, image.width, image.height, pixels);
    }

    // TODO: toVgImage function for using textures in NanoVG
    pub fn toVgImage(self: *Texture, vg: nvg) nvg.Image {
        if (self.nvgHandle) |handle| {
            return .{ .handle = handle };
        } else {
            const ctx = @as(*nvg.gl.GLContext, @ptrCast(@alignCast(vg.ctx.params.user_ptr)));
            var tex = ctx.allocTexture() catch unreachable;
            tex.width = @as(i32, @intCast(self.width));
            tex.height = @as(i32, @intCast(self.height));
            tex.tex = self.texture;
            tex.flags = .{};
            tex.tex_type = .rgba;

            self.nvgHandle = tex.id;
            return .{ .handle = tex.id };
        }
    }

    pub fn deinit(self: *Texture) void {
        // TODO
        _ = self;
    }
};

pub const TextureCache = struct {
    cache: std.StringHashMap(Texture),

    pub fn init(allocator: Allocator) TextureCache {
        return TextureCache{ .cache = std.StringHashMap(Texture).init(allocator) };
    }

    pub fn get(self: *TextureCache, name: []const u8) *Texture {
        return getExt(self, name, .{});
    }

    pub const TextureOptions = struct {
        mipmaps: bool = false,
    };

    pub fn getExt(self: *TextureCache, name: []const u8, options: TextureOptions) *Texture {
        if (self.cache.getPtr(name)) |texture| {
            return texture;
        } else {
            const path = std.mem.concat(self.cache.allocator, u8, &[_][]const u8{ "assets/", name, ".png" }) catch unreachable;
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

            return self.cache.getPtr(name).?;
        }
    }

    pub fn deinit(self: *TextureCache) void {
        self.cache.deinit();
    }
};

const Shader = struct {
    shader: gl.GLuint,

    pub fn create(kind: gl.GLenum) Shader {
        return Shader{ .shader = gl.createShader(kind) };
    }

    pub fn setSource(self: Shader, source: [:0]const u8) void {
        gl.shaderSource(self.shader, 1, &[_][*c]const u8{source.ptr}, null);
    }

    pub fn compile(self: Shader) !void {
        gl.compileShader(self.shader);

        var successful: c_int = undefined;
        gl.getShaderiv(self.shader, gl.COMPILE_STATUS, &successful);
        if (successful != gl.TRUE) {
            var infoLogLen: c_int = undefined;
            gl.getShaderiv(self.shader, gl.INFO_LOG_LENGTH, &infoLogLen);

            const allocator = std.heap.page_allocator; // it's for an error case so
            const infoLog = allocator.allocSentinel(u8, @as(usize, @intCast(infoLogLen)), 0) catch {
                log.err("Could not get info log: out of memory", .{});
                return error.CompileError;
            };
            defer allocator.free(infoLog);

            gl.getShaderInfoLog(self.shader, infoLogLen, null, infoLog.ptr);
            log.err("shader compile error: {s}", .{infoLog});

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
        return ShaderProgram{ .program = gl.createProgram() };
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

        vertexShader.setSource(try allocator.dupeZ(u8, try vertexFile.readToEndAlloc(allocator, std.math.maxInt(usize))));
        try vertexShader.compile();

        const fragmentShader = Shader.create(gl.FRAGMENT_SHADER);
        defer fragmentShader.deinit();

        const fragmentFile = try std.fs.cwd().openFile(path ++ ".fs", .{});
        defer fragmentFile.close();

        fragmentShader.setSource(try allocator.dupeZ(u8, try fragmentFile.readToEndAlloc(allocator, std.math.maxInt(usize))));
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

    pub fn setUniformBool(self: ShaderProgram, uniform: [:0]const u8, boolean: bool) void {
        self.setUniformInt(uniform, @intFromBool(boolean));
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

pub const Framebuffer = struct {
    fbo: gl.GLuint,
    colorTextures: [2]gl.GLuint,
    depthTexture: gl.GLuint,
    width: c_int,
    height: c_int,

    pub fn create(width: c_int, height: c_int) !Framebuffer {
        var fbo: gl.GLuint = undefined;
        gl.genFramebuffers(1, &fbo);
        gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
        defer gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

        var colorTextures: [2]gl.GLuint = undefined;
        gl.genTextures(2, &colorTextures);
        for (colorTextures, 0..) |colorTexture, i| {
            gl.bindTexture(gl.TEXTURE_2D, colorTexture);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, null);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
            gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0 + @as(c_uint, @intCast(i)), gl.TEXTURE_2D, colorTexture, 0);
        }

        var depthTexture: gl.GLuint = undefined;
        gl.genTextures(1, &depthTexture);
        gl.bindTexture(gl.TEXTURE_2D, depthTexture);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, width, height, 0, gl.DEPTH_COMPONENT, gl.FLOAT, null);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, depthTexture, 0);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

        const attachments: [2]gl.GLenum = .{ gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1 };
        gl.drawBuffers(2, &attachments);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
            return error.IncompleteFramebuffer;
        }

        return Framebuffer{
            .fbo = fbo,
            .colorTextures = colorTextures,
            .depthTexture = depthTexture,
            .width = width,
            .height = height,
        };
    }

    pub fn bind(self: Framebuffer) void {
        gl.bindFramebuffer(gl.FRAMEBUFFER, self.fbo);
    }

    pub fn unbind(_: Framebuffer) void {
        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
    }

    pub fn deinit(self: Framebuffer) void {
        gl.deleteFramebuffers(1, &self.fbo);
        gl.deleteTextures(2, &self.colorTextures);
        gl.deleteTextures(1, &self.depthTexture);
    }
};
