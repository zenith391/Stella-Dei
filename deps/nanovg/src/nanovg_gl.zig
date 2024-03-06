const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const use_webgl = builtin.cpu.arch.isWasm();
const gl = if (use_webgl)
    @import("web/webgl.zig")
else
    @import("root").gl;
const print = if (builtin.cpu.arch.isWasm()) @import("web/console.zig").log else std.debug.print;

const nvg = @import("nanovg.zig");
const internal = @import("internal.zig");

pub const Options = struct {
    antialias: bool = false,
    stencil_strokes: bool = false,
    debug: bool = false,
};

pub fn init(allocator: Allocator, options: Options) !nvg {
    const gl_context = try GLContext.init(allocator, options);

    const params = internal.Params{
        .user_ptr = gl_context,
        .edge_antialias = options.antialias,
        .renderCreate = renderCreate,
        .renderCreateTexture = renderCreateTexture,
        .renderDeleteTexture = renderDeleteTexture,
        .renderUpdateTexture = renderUpdateTexture,
        .renderGetTextureSize = renderGetTextureSize,
        .renderViewport = renderViewport,
        .renderCancel = renderCancel,
        .renderFlush = renderFlush,
        .renderFill = renderFill,
        .renderStroke = renderStroke,
        .renderTriangles = renderTriangles,
        .renderDelete = renderDelete,
    };
    return nvg{
        .ctx = try internal.Context.init(allocator, params),
    };
}

pub const GLContext = struct {
    allocator: Allocator,
    options: Options,
    shader: Shader,
    view: [2]f32,
    textures: ArrayList(Texture),
    texture_id: i32 = 0,
    vert_buf: gl.GLuint = 0,
    calls: ArrayList(Call),
    paths: ArrayList(Path),
    verts: ArrayList(internal.Vertex),
    uniforms: ArrayList(FragUniforms),

    fn init(allocator: Allocator, options: Options) !*GLContext {
        const self = try allocator.create(GLContext);
        self.* = GLContext{
            .allocator = allocator,
            .options = options,
            .shader = undefined,
            .view = .{ 0, 0 },
            .textures = ArrayList(Texture).init(allocator),
            .calls = ArrayList(Call).init(allocator),
            .paths = ArrayList(Path).init(allocator),
            .verts = ArrayList(internal.Vertex).init(allocator),
            .uniforms = ArrayList(FragUniforms).init(allocator),
        };
        return self;
    }

    fn deinit(ctx: *GLContext) void {
        ctx.shader.delete();
        ctx.textures.deinit();
        ctx.calls.deinit();
        ctx.paths.deinit();
        ctx.verts.deinit();
        ctx.uniforms.deinit();
        ctx.allocator.destroy(ctx);
    }

    fn castPtr(ptr: *anyopaque) *GLContext {
        return @as(*GLContext, @ptrCast(@alignCast(ptr)));
    }

    fn checkError(ctx: GLContext, str: []const u8) void {
        if (!ctx.options.debug) return;
        const err = gl.getError();
        if (err != gl.NO_ERROR) {
            print("GLError {X:0>8} after {s}\n", .{ err, str });
        }
    }

    pub fn allocTexture(ctx: *GLContext) !*Texture {
        var found_tex: ?*Texture = null;
        for (ctx.textures.items) |*tex| {
            if (tex.id == 0) {
                found_tex = tex;
                break;
            }
        }
        if (found_tex == null) {
            found_tex = try ctx.textures.addOne();
        }
        const tex = found_tex.?;
        tex.* = std.mem.zeroes(Texture);
        ctx.texture_id += 1;
        tex.id = ctx.texture_id;

        return tex;
    }

    fn findTexture(ctx: *GLContext, id: i32) ?*Texture {
        for (ctx.textures.items) |*tex| {
            if (tex.id == id) return tex;
        }
        return null;
    }
};

const ShaderType = enum(u2) {
    fill_gradient,
    fill_image,
    simple,
    image,
};

const Shader = struct {
    prog: gl.GLuint,
    frag: gl.GLuint,
    vert: gl.GLuint,

    view_loc: gl.GLint,
    tex_loc: gl.GLint,
    colormap_loc: gl.GLint,
    frag_loc: gl.GLint,

    fn create(shader: *Shader, header: [:0]const u8, vertsrc: [:0]const u8, fragsrc: [:0]const u8) !void {
        var status: gl.GLint = undefined;
        var str: [2][*]const u8 = undefined;
        var len: [2]gl.GLint = undefined;
        str[0] = header.ptr;
        len[0] = @as(gl.GLint, @intCast(header.len));

        shader.* = std.mem.zeroes(Shader);

        const prog = gl.createProgram();
        const vert = gl.createShader(gl.VERTEX_SHADER);
        const frag = gl.createShader(gl.FRAGMENT_SHADER);
        str[1] = vertsrc.ptr;
        len[1] = @as(gl.GLint, @intCast(vertsrc.len));
        gl.shaderSource(vert, 2, &str[0], &len[0]);
        str[1] = fragsrc.ptr;
        len[1] = @as(gl.GLint, @intCast(fragsrc.len));
        gl.shaderSource(frag, 2, &str[0], &len[0]);

        gl.compileShader(vert);
        gl.getShaderiv(vert, gl.COMPILE_STATUS, &status);
        if (status != gl.TRUE) {
            printShaderErrorLog(vert, "shader", "vert");
            return error.ShaderCompilationFailed;
        }

        gl.compileShader(frag);
        gl.getShaderiv(frag, gl.COMPILE_STATUS, &status);
        if (status != gl.TRUE) {
            printShaderErrorLog(frag, "shader", "frag");
            return error.ShaderCompilationFailed;
        }

        gl.attachShader(prog, vert);
        gl.attachShader(prog, frag);

        gl.bindAttribLocation(prog, 0, "vertex");
        gl.bindAttribLocation(prog, 1, "tcoord");

        gl.linkProgram(prog);
        gl.getProgramiv(prog, gl.LINK_STATUS, &status);
        if (status != gl.TRUE) {
            printProgramErrorLog(prog, "shader");
            return error.ProgramLinkingFailed;
        }

        shader.prog = prog;
        shader.vert = vert;
        shader.frag = frag;

        shader.getUniformLocations();
    }

    fn delete(shader: Shader) void {
        if (shader.prog != 0) gl.deleteProgram(shader.prog);
        if (shader.vert != 0) gl.deleteShader(shader.vert);
        if (shader.frag != 0) gl.deleteShader(shader.frag);
    }

    fn getUniformLocations(shader: *Shader) void {
        shader.view_loc = gl.getUniformLocation(shader.prog, "viewSize");
        shader.tex_loc = gl.getUniformLocation(shader.prog, "tex");
        shader.colormap_loc = gl.getUniformLocation(shader.prog, "colormap");
        shader.frag_loc = gl.getUniformLocation(shader.prog, "frag");
    }

    fn printShaderErrorLog(shader: gl.GLuint, name: []const u8, shader_type: []const u8) void {
        var buf: [512]gl.GLchar = undefined;
        var len: gl.GLsizei = 0;
        gl.getShaderInfoLog(shader, 512, &len, &buf[0]);
        if (len > 512) len = 512;
        const log = buf[0..@as(usize, @intCast(len))];
        print("Shader {s}/{s} error:\n{s}\n", .{ name, shader_type, log });
    }

    fn printProgramErrorLog(program: gl.GLuint, name: []const u8) void {
        var buf: [512]gl.GLchar = undefined;
        var len: gl.GLsizei = 0;
        gl.getProgramInfoLog(program, 512, &len, &buf[0]);
        if (len > 512) len = 512;
        const log = buf[0..@as(usize, @intCast(len))];
        print("Program {s} error:\n{s}\n", .{ name, log });
    }
};

const Texture = struct {
    id: i32,
    tex: gl.GLuint,
    width: i32,
    height: i32,
    tex_type: internal.TextureType,
    flags: nvg.ImageFlags,
};

const Blend = struct {
    src_rgb: gl.GLenum,
    dst_rgb: gl.GLenum,
    src_alpha: gl.GLenum,
    dst_alpha: gl.GLenum,

    fn fromOperation(op: nvg.CompositeOperationState) Blend {
        return .{
            .src_rgb = convertBlendFuncFactor(op.src_rgb),
            .dst_rgb = convertBlendFuncFactor(op.dst_rgb),
            .src_alpha = convertBlendFuncFactor(op.src_alpha),
            .dst_alpha = convertBlendFuncFactor(op.dst_alpha),
        };
    }

    fn convertBlendFuncFactor(factor: nvg.BlendFactor) gl.GLenum {
        return switch (factor) {
            .zero => gl.ZERO,
            .one => gl.ONE,
            .src_color => gl.SRC_COLOR,
            .one_minus_src_color => gl.ONE_MINUS_SRC_COLOR,
            .dst_color => gl.DST_COLOR,
            .one_minus_dst_color => gl.ONE_MINUS_DST_COLOR,
            .src_alpha => gl.SRC_ALPHA,
            .one_minus_src_alpha => gl.ONE_MINUS_SRC_ALPHA,
            .dst_alpha => gl.DST_ALPHA,
            .one_minus_dst_alpha => gl.ONE_MINUS_DST_ALPHA,
            .src_alpha_saturate => gl.SRC_ALPHA_SATURATE,
        };
    }
};

const call_type = enum {
    none,
    fill,
    convexfill,
    stroke,
    triangles,
};

const Call = struct {
    call_type: call_type,
    image: i32,
    colormap: i32,
    path_offset: u32,
    path_count: u32,
    triangle_offset: u32,
    triangle_count: u32,
    uniform_offset: u32,
    blend_func: Blend,

    fn fill(call: Call, ctx: *GLContext) void {
        const paths = ctx.paths.items[call.path_offset..][0..call.path_count];

        // Draw shapes
        gl.enable(gl.STENCIL_TEST);
        defer gl.disable(gl.STENCIL_TEST);
        gl.stencilMask(0xff);
        gl.stencilFunc(gl.ALWAYS, 0x0, 0xff);
        gl.colorMask(gl.FALSE, gl.FALSE, gl.FALSE, gl.FALSE);

        // set bindpoint for solid loc
        setUniforms(ctx, call.uniform_offset, 0, 0);
        ctx.checkError("fill simple");

        gl.stencilOpSeparate(gl.FRONT, gl.KEEP, gl.KEEP, gl.INCR_WRAP);
        gl.stencilOpSeparate(gl.BACK, gl.KEEP, gl.KEEP, gl.DECR_WRAP);
        gl.disable(gl.CULL_FACE);
        for (paths) |path| {
            gl.drawArrays(gl.TRIANGLE_FAN, @as(gl.GLint, @intCast(path.fill_offset)), @as(gl.GLsizei, @intCast(path.fill_count)));
        }
        gl.enable(gl.CULL_FACE);

        // Draw anti-aliased pixels
        gl.colorMask(gl.TRUE, gl.TRUE, gl.TRUE, gl.TRUE);

        setUniforms(ctx, call.uniform_offset + 1, call.image, call.colormap);
        ctx.checkError("fill fill");

        if (ctx.options.antialias) {
            gl.stencilFunc(gl.EQUAL, 0x00, 0xff);
            gl.stencilOp(gl.KEEP, gl.KEEP, gl.KEEP);
            // Draw fringes
            for (paths) |path| {
                gl.drawArrays(gl.TRIANGLE_STRIP, @as(gl.GLint, @intCast(path.stroke_offset)), @as(gl.GLsizei, @intCast(path.stroke_count)));
            }
        }

        // Draw fill
        gl.stencilFunc(gl.NOTEQUAL, 0x0, 0xff);
        gl.stencilOp(gl.ZERO, gl.ZERO, gl.ZERO);
        gl.drawArrays(gl.TRIANGLE_STRIP, @as(gl.GLint, @intCast(call.triangle_offset)), @as(gl.GLsizei, @intCast(call.triangle_count)));
    }

    fn convexFill(call: Call, ctx: *GLContext) void {
        const paths = ctx.paths.items[call.path_offset..][0..call.path_count];

        setUniforms(ctx, call.uniform_offset, call.image, call.colormap);
        ctx.checkError("convex fill");

        for (paths) |path| {
            gl.drawArrays(gl.TRIANGLE_FAN, @as(gl.GLint, @intCast(path.fill_offset)), @as(gl.GLsizei, @intCast(path.fill_count)));
            // Draw fringes
            if (path.stroke_count > 0) {
                gl.drawArrays(gl.TRIANGLE_STRIP, @as(gl.GLint, @intCast(path.stroke_offset)), @as(gl.GLsizei, @intCast(path.stroke_count)));
            }
        }
    }

    fn stroke(call: Call, ctx: *GLContext) void {
        const paths = ctx.paths.items[call.path_offset..][0..call.path_count];

        if (ctx.options.stencil_strokes) {
            gl.enable(gl.STENCIL_TEST);
            defer gl.disable(gl.STENCIL_TEST);

            gl.stencilMask(0xff);

            // Fill the stroke base without overlap
            gl.stencilFunc(gl.EQUAL, 0x0, 0xff);
            gl.stencilOp(gl.KEEP, gl.KEEP, gl.INCR);
            setUniforms(ctx, call.uniform_offset + 1, call.image, call.colormap);
            ctx.checkError("stroke fill 0");
            for (paths) |path| {
                gl.drawArrays(gl.TRIANGLE_STRIP, @as(gl.GLint, @intCast(path.stroke_offset)), @as(gl.GLsizei, @intCast(path.stroke_count)));
            }

            // Draw anti-aliased pixels.
            setUniforms(ctx, call.uniform_offset, call.image, call.colormap);
            gl.stencilFunc(gl.EQUAL, 0x00, 0xff);
            gl.stencilOp(gl.KEEP, gl.KEEP, gl.KEEP);
            for (paths) |path| {
                gl.drawArrays(gl.TRIANGLE_STRIP, @as(gl.GLint, @intCast(path.stroke_offset)), @as(gl.GLsizei, @intCast(path.stroke_count)));
            }

            // Clear stencil buffer.
            gl.colorMask(gl.FALSE, gl.FALSE, gl.FALSE, gl.FALSE);
            gl.stencilFunc(gl.ALWAYS, 0x0, 0xff);
            gl.stencilOp(gl.ZERO, gl.ZERO, gl.ZERO);
            ctx.checkError("stroke fill 1");
            for (paths) |path| {
                gl.drawArrays(gl.TRIANGLE_STRIP, @as(gl.GLint, @intCast(path.stroke_offset)), @as(gl.GLsizei, @intCast(path.stroke_count)));
            }
            gl.colorMask(gl.TRUE, gl.TRUE, gl.TRUE, gl.TRUE);
        } else {
            setUniforms(ctx, call.uniform_offset, call.image, call.colormap);
            // Draw Strokes
            for (paths) |path| {
                gl.drawArrays(gl.TRIANGLE_STRIP, @as(gl.GLint, @intCast(path.stroke_offset)), @as(gl.GLsizei, @intCast(path.stroke_count)));
            }
        }
    }

    fn triangles(call: Call, ctx: *GLContext) void {
        setUniforms(ctx, call.uniform_offset, call.image, call.colormap);
        ctx.checkError("triangles fill");
        gl.drawArrays(gl.TRIANGLES, @as(gl.GLint, @intCast(call.triangle_offset)), @as(gl.GLsizei, @intCast(call.triangle_count)));
    }
};

const Path = struct {
    fill_offset: u32,
    fill_count: u32,
    stroke_offset: u32,
    stroke_count: u32,
};

fn maxVertCount(paths: []const internal.Path) usize {
    var count: usize = 0;
    for (paths) |path| {
        count += path.fill.len;
        count += path.stroke.len;
    }
    return count;
}

fn xformToMat3x4(m3: *[12]f32, t: *const [6]f32) void {
    m3[0] = t[0];
    m3[1] = t[1];
    m3[2] = 0;
    m3[3] = 0;
    m3[4] = t[2];
    m3[5] = t[3];
    m3[6] = 0;
    m3[7] = 0;
    m3[8] = t[4];
    m3[9] = t[5];
    m3[10] = 1;
    m3[11] = 0;
}

fn premulColor(c: nvg.Color) nvg.Color {
    return .{ .r = c.r * c.a, .g = c.g * c.a, .b = c.b * c.a, .a = c.a };
}

const FragUniforms = struct {
    scissor_mat: [12]f32, // matrices are actually 3 vec4s
    paint_mat: [12]f32,
    inner_color: nvg.Color,
    outer_color: nvg.Color,
    scissor_extent: [2]f32,
    scissor_scale: [2]f32,
    extent: [2]f32,
    radius: f32,
    feather: f32,
    stroke_mult: f32,
    stroke_thr: f32,
    tex_type: f32,
    shaderType: f32,

    fn fromPaint(frag: *FragUniforms, paint: *nvg.Paint, scissor: *internal.Scissor, width: f32, fringe: f32, stroke_thr: f32, ctx: *GLContext) i32 {
        var invxform: [6]f32 = undefined;

        frag.* = std.mem.zeroes(FragUniforms);

        frag.inner_color = premulColor(paint.inner_color);
        frag.outer_color = premulColor(paint.outer_color);

        if (scissor.extent[0] < -0.5 or scissor.extent[1] < -0.5) {
            @memset(&frag.scissor_mat, 0);
            frag.scissor_extent[0] = 1;
            frag.scissor_extent[1] = 1;
            frag.scissor_scale[0] = 1;
            frag.scissor_scale[1] = 1;
        } else {
            _ = nvg.transformInverse(&invxform, &scissor.xform);
            xformToMat3x4(&frag.scissor_mat, &invxform);
            frag.scissor_extent[0] = scissor.extent[0];
            frag.scissor_extent[1] = scissor.extent[1];
            frag.scissor_scale[0] = @sqrt(scissor.xform[0] * scissor.xform[0] + scissor.xform[2] * scissor.xform[2]) / fringe;
            frag.scissor_scale[1] = @sqrt(scissor.xform[1] * scissor.xform[1] + scissor.xform[3] * scissor.xform[3]) / fringe;
        }

        @memcpy(&frag.extent, &paint.extent);
        frag.stroke_mult = (width * 0.5 + fringe * 0.5) / fringe;
        frag.stroke_thr = stroke_thr;

        if (paint.image.handle != 0) {
            const tex = ctx.findTexture(paint.image.handle) orelse return 0;
            if (tex.flags.flip_y) {
                var m1: [6]f32 = undefined;
                var m2: [6]f32 = undefined;
                nvg.transformTranslate(&m1, 0, frag.extent[1] * 0.5);
                nvg.transformMultiply(&m1, &paint.xform);
                nvg.transformScale(&m2, 1, -1);
                nvg.transformMultiply(&m2, &m1);
                nvg.transformTranslate(&m1, 0, -frag.extent[1] * 0.5);
                nvg.transformMultiply(&m1, &m2);
                _ = nvg.transformInverse(&invxform, &m1);
            } else {
                _ = nvg.transformInverse(&invxform, &paint.xform);
            }
            frag.shaderType = @as(f32, @floatFromInt(@intFromEnum(ShaderType.fill_image)));

            if (tex.tex_type == .rgba) {
                frag.tex_type = if (tex.flags.premultiplied) 0 else 1;
            } else if (paint.colormap.handle == 0) {
                frag.tex_type = 2;
            } else {
                frag.tex_type = 3;
            }
        } else {
            frag.shaderType = @as(f32, @floatFromInt(@intFromEnum(ShaderType.fill_gradient)));
            frag.radius = paint.radius;
            frag.feather = paint.feather;
            _ = nvg.transformInverse(&invxform, &paint.xform);
        }

        xformToMat3x4(&frag.paint_mat, &invxform);

        return 1;
    }
};

fn setUniforms(ctx: *GLContext, uniform_offset: u32, image: i32, colormap: i32) void {
    const frag = &ctx.uniforms.items[uniform_offset];
    gl.uniform4fv(ctx.shader.frag_loc, 11, @as([*]f32, @ptrCast(frag)));

    if (colormap != 0) {
        if (ctx.findTexture(colormap)) |tex| {
            gl.activeTexture(gl.TEXTURE0 + 1);
            gl.bindTexture(gl.TEXTURE_2D, tex.tex);
            gl.activeTexture(gl.TEXTURE0 + 0);
        }
    }

    if (image != 0) {
        if (ctx.findTexture(image)) |tex| {
            gl.bindTexture(gl.TEXTURE_2D, tex.tex);
        }
    }
    // // If no image is set, use empty texture
    // if (tex == NULL) {
    // 	tex = glnvg__findTexture(gl->dummyTex);
    // }
    // glnvg__bindTexture(tex != NULL ? tex->tex : 0);
    ctx.checkError("tex paint tex");
}

fn renderCreate(uptr: *anyopaque) !void {
    const ctx = GLContext.castPtr(uptr);

    const vertSrc = @embedFile("glsl/fill.vert");
    const fragSrc = @embedFile("glsl/fill.frag");
    const fragHeader = if (ctx.options.antialias) "#define EDGE_AA 1\n" else "";
    try ctx.shader.create(fragHeader, vertSrc, fragSrc);

    gl.genBuffers(1, &ctx.vert_buf);

    // Some platforms does not allow to have samples to unset textures.
    // Create empty one which is bound when there's no texture specified.
    // ctx.dummyTex = glnvg__renderCreateTexture(NVG_TEXTURE_ALPHA, 1, 1, 0, NULL);
}

fn renderCreateTexture(uptr: *anyopaque, tex_type: internal.TextureType, w: i32, h: i32, flags: nvg.ImageFlags, data: ?[*]const u8) !i32 {
    const ctx = GLContext.castPtr(uptr);
    var tex: *Texture = try ctx.allocTexture();

    gl.genTextures(1, &tex.tex);
    tex.width = w;
    tex.height = h;
    tex.tex_type = tex_type;
    tex.flags = flags;
    gl.bindTexture(gl.TEXTURE_2D, tex.tex);

    if (!use_webgl) {
        // GL 1.4 and later has support for generating mipmaps using a tex parameter.
        if (flags.generate_mipmaps) {
            gl.generateMipmap(gl.TEXTURE_2D);
        }
    }

    switch (tex_type) {
        .none => {},
        .alpha => gl.texImage2D(gl.TEXTURE_2D, 0, gl.RED, w, h, 0, gl.RED, gl.UNSIGNED_BYTE, data),
        .rgba => gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, data),
    }

    if (flags.generate_mipmaps) {
        const min_filter: gl.GLint = if (flags.nearest) gl.NEAREST_MIPMAP_NEAREST else gl.LINEAR_MIPMAP_LINEAR;
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, min_filter);
    } else {
        const min_filter: gl.GLint = if (flags.nearest) gl.NEAREST else gl.LINEAR;
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, min_filter);
    }
    const mag_filter: gl.GLint = if (flags.nearest) gl.NEAREST else gl.LINEAR;
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, mag_filter);

    const wrap_s: gl.GLint = if (flags.repeat_x) gl.REPEAT else gl.CLAMP_TO_EDGE;
    const wrap_t: gl.GLint = if (flags.repeat_y) gl.REPEAT else gl.CLAMP_TO_EDGE;
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_s);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_t);

    if (use_webgl) {
        if (flags.generate_mipmaps) {
            gl.generateMipmap(gl.TEXTURE_2D);
        }
    }

    return tex.id;
}

fn renderDeleteTexture(uptr: *anyopaque, image: i32) void {
    const ctx = GLContext.castPtr(uptr);
    const tex = ctx.findTexture(image) orelse return;
    if (tex.tex != 0) gl.deleteTextures(1, &tex.tex);
    tex.* = std.mem.zeroes(Texture);
}

fn renderUpdateTexture(uptr: *anyopaque, image: i32, x_arg: i32, y: i32, w_arg: i32, h: i32, data_arg: ?[*]const u8) i32 {
    _ = x_arg;
    _ = w_arg;
    const ctx = GLContext.castPtr(uptr);
    const tex = ctx.findTexture(image) orelse return 0;

    // No support for all of skip, need to update a whole row at a time.
    const color_size: u32 = if (tex.tex_type == .rgba) 4 else 1;
    const y0: u32 = @as(u32, @intCast(y * tex.width));
    const data = &data_arg.?[y0 * color_size];
    const x = 0;
    const w = tex.width;

    gl.bindTexture(gl.TEXTURE_2D, tex.tex);
    switch (tex.tex_type) {
        .none => {},
        .alpha => gl.texSubImage2D(gl.TEXTURE_2D, 0, x, y, w, h, gl.RED, gl.UNSIGNED_BYTE, data),
        .rgba => gl.texSubImage2D(gl.TEXTURE_2D, 0, x, y, w, h, gl.RGBA, gl.UNSIGNED_BYTE, data),
    }
    gl.bindTexture(gl.TEXTURE_2D, 0);

    return 1;
}

fn renderGetTextureSize(uptr: *anyopaque, image: i32, w: *i32, h: *i32) i32 {
    const ctx = GLContext.castPtr(uptr);
    const tex = ctx.findTexture(image) orelse return 0;
    w.* = tex.width;
    h.* = tex.height;
    return 1;
}

fn renderViewport(uptr: *anyopaque, width: f32, height: f32, devicePixelRatio: f32) void {
    const ctx = GLContext.castPtr(uptr);
    ctx.view[0] = width;
    ctx.view[1] = height;
    _ = devicePixelRatio;
}

fn renderCancel(uptr: *anyopaque) void {
    const ctx = GLContext.castPtr(uptr);
    ctx.verts.clearRetainingCapacity();
    ctx.paths.clearRetainingCapacity();
    ctx.calls.clearRetainingCapacity();
    ctx.uniforms.clearRetainingCapacity();
}

fn renderFlush(uptr: *anyopaque) void {
    const ctx = GLContext.castPtr(uptr);

    if (ctx.calls.items.len > 0) {
        // Setup required GL state.
        gl.useProgram(ctx.shader.prog);

        gl.enable(gl.CULL_FACE);
        gl.cullFace(gl.BACK);
        gl.frontFace(gl.CCW);
        gl.enable(gl.BLEND);
        gl.disable(gl.DEPTH_TEST);
        gl.disable(gl.SCISSOR_TEST);
        gl.colorMask(gl.TRUE, gl.TRUE, gl.TRUE, gl.TRUE);
        gl.stencilMask(0xffffffff);
        gl.stencilOp(gl.KEEP, gl.KEEP, gl.KEEP);
        gl.stencilFunc(gl.ALWAYS, 0, 0xffffffff);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, 0);

        gl.bindBuffer(gl.ARRAY_BUFFER, ctx.vert_buf);
        gl.bufferData(gl.ARRAY_BUFFER, @as(gl.GLsizeiptr, @intCast(ctx.verts.items.len * @sizeOf(internal.Vertex))), ctx.verts.items.ptr, gl.STREAM_DRAW);
        gl.enableVertexAttribArray(0);
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, @sizeOf(internal.Vertex), null);
        gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, @sizeOf(internal.Vertex), @as(*anyopaque, @ptrFromInt(2 * @sizeOf(f32))));

        // Set view and texture just once per frame.
        gl.uniform1i(ctx.shader.tex_loc, 0);
        gl.uniform1i(ctx.shader.colormap_loc, 1);
        gl.uniform2fv(ctx.shader.view_loc, 1, &ctx.view[0]);

        for (ctx.calls.items) |call| {
            gl.blendFuncSeparate(call.blend_func.src_rgb, call.blend_func.dst_rgb, call.blend_func.src_alpha, call.blend_func.dst_alpha);
            switch (call.call_type) {
                .none => {},
                .fill => call.fill(ctx),
                .convexfill => call.convexFill(ctx),
                .stroke => call.stroke(ctx),
                .triangles => call.triangles(ctx),
            }
        }

        gl.disableVertexAttribArray(0);
        gl.disableVertexAttribArray(1);
        gl.disable(gl.CULL_FACE);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.useProgram(0);
        gl.bindTexture(gl.TEXTURE_2D, 0);
    }

    // Reset calls
    ctx.verts.clearRetainingCapacity();
    ctx.paths.clearRetainingCapacity();
    ctx.calls.clearRetainingCapacity();
    ctx.uniforms.clearRetainingCapacity();
}

fn renderFill(uptr: *anyopaque, paint: *nvg.Paint, composite_operation: nvg.CompositeOperationState, scissor: *internal.Scissor, fringe: f32, bounds: [4]f32, paths: []const internal.Path) void {
    const ctx = GLContext.castPtr(uptr);

    const call = ctx.calls.addOne() catch return;
    call.* = std.mem.zeroes(Call);

    call.call_type = .fill;
    call.triangle_count = 4;
    if (paths.len == 1 and paths[0].convex) {
        call.call_type = .convexfill;
        call.triangle_count = 0; // Bounding box fill quad not needed for convex fill
    }
    ctx.paths.ensureUnusedCapacity(paths.len) catch return;
    call.path_offset = @as(u32, @intCast(ctx.paths.items.len));
    call.path_count = @as(u32, @intCast(paths.len));
    call.image = paint.image.handle;
    call.colormap = paint.colormap.handle;
    call.blend_func = Blend.fromOperation(composite_operation);

    // Allocate vertices for all the paths.
    const maxverts = maxVertCount(paths) + call.triangle_count;
    ctx.verts.ensureUnusedCapacity(maxverts) catch return;

    for (paths) |path| {
        const copy = ctx.paths.addOneAssumeCapacity();
        copy.* = std.mem.zeroes(Path);
        if (path.fill.len > 0) {
            copy.fill_offset = @as(u32, @intCast(ctx.verts.items.len));
            copy.fill_count = @as(u32, @intCast(path.fill.len));
            ctx.verts.appendSliceAssumeCapacity(path.fill);
        }
        if (path.stroke.len > 0) {
            copy.stroke_offset = @as(u32, @intCast(ctx.verts.items.len));
            copy.stroke_count = @as(u32, @intCast(path.stroke.len));
            ctx.verts.appendSliceAssumeCapacity(path.stroke);
        }
    }

    // Setup uniforms for draw calls
    if (call.call_type == .fill) {
        // Quad
        call.triangle_offset = @as(u32, @intCast(ctx.verts.items.len));
        ctx.verts.appendAssumeCapacity(.{ .x = bounds[2], .y = bounds[3], .u = 0.5, .v = 1.0 });
        ctx.verts.appendAssumeCapacity(.{ .x = bounds[2], .y = bounds[1], .u = 0.5, .v = 1.0 });
        ctx.verts.appendAssumeCapacity(.{ .x = bounds[0], .y = bounds[3], .u = 0.5, .v = 1.0 });
        ctx.verts.appendAssumeCapacity(.{ .x = bounds[0], .y = bounds[1], .u = 0.5, .v = 1.0 });

        call.uniform_offset = @as(u32, @intCast(ctx.uniforms.items.len));
        ctx.uniforms.ensureUnusedCapacity(2) catch return;
        // Simple shader for stencil
        const frag = ctx.uniforms.addOneAssumeCapacity();
        frag.* = std.mem.zeroes(FragUniforms);
        frag.stroke_thr = -1.0;
        frag.shaderType = @as(f32, @floatFromInt(@intFromEnum(ShaderType.simple)));
        // Fill shader
        _ = ctx.uniforms.addOneAssumeCapacity().fromPaint(paint, scissor, fringe, fringe, -1.0, ctx);
    } else {
        call.uniform_offset = @as(u32, @intCast(ctx.uniforms.items.len));
        ctx.uniforms.ensureUnusedCapacity(1) catch return;
        // Fill shader
        _ = ctx.uniforms.addOneAssumeCapacity().fromPaint(paint, scissor, fringe, fringe, -1.0, ctx);
    }
}

fn renderStroke(uptr: *anyopaque, paint: *nvg.Paint, composite_operation: nvg.CompositeOperationState, scissor: *internal.Scissor, fringe: f32, strokeWidth: f32, paths: []const internal.Path) void {
    const ctx = GLContext.castPtr(uptr);

    const call = ctx.calls.addOne() catch return;
    call.* = std.mem.zeroes(Call);

    call.call_type = .stroke;
    ctx.paths.ensureUnusedCapacity(paths.len) catch return;
    call.path_offset = @as(u32, @intCast(ctx.paths.items.len));
    call.path_count = @as(u32, @intCast(paths.len));
    call.image = paint.image.handle;
    call.colormap = paint.colormap.handle;
    call.blend_func = Blend.fromOperation(composite_operation);

    // Allocate vertices for all the paths.
    const maxverts = maxVertCount(paths);
    ctx.verts.ensureUnusedCapacity(maxverts) catch return;

    for (paths) |path| {
        const copy = ctx.paths.addOneAssumeCapacity();
        copy.* = std.mem.zeroes(Path);
        if (path.stroke.len > 0) {
            copy.stroke_offset = @as(u32, @intCast(ctx.verts.items.len));
            copy.stroke_count = @as(u32, @intCast(path.stroke.len));
            ctx.verts.appendSliceAssumeCapacity(path.stroke);
        }
    }

    if (ctx.options.stencil_strokes) {
        // Fill shader
        call.uniform_offset = @as(u32, @intCast(ctx.uniforms.items.len));
        ctx.uniforms.ensureUnusedCapacity(2) catch return;
        _ = ctx.uniforms.addOneAssumeCapacity().fromPaint(paint, scissor, fringe, fringe, -1, ctx);
        _ = ctx.uniforms.addOneAssumeCapacity().fromPaint(paint, scissor, strokeWidth, fringe, 1.0 - 0.5 / 255.0, ctx);
    } else {
        // Fill shader
        call.uniform_offset = @as(u32, @intCast(ctx.uniforms.items.len));
        _ = ctx.uniforms.ensureUnusedCapacity(1) catch return;
        _ = ctx.uniforms.addOneAssumeCapacity().fromPaint(paint, scissor, strokeWidth, fringe, -1, ctx);
    }
}

fn renderTriangles(uptr: *anyopaque, paint: *nvg.Paint, comp_op: nvg.CompositeOperationState, scissor: *internal.Scissor, fringe: f32, verts: []const internal.Vertex) void {
    const ctx = GLContext.castPtr(uptr);

    const call = ctx.calls.addOne() catch return;
    call.* = std.mem.zeroes(Call);

    call.call_type = .triangles;
    call.image = paint.image.handle;
    call.colormap = paint.colormap.handle;
    call.blend_func = Blend.fromOperation(comp_op);

    call.triangle_offset = @as(u32, @intCast(ctx.verts.items.len));
    call.triangle_count = @as(u32, @intCast(verts.len));
    ctx.verts.appendSlice(verts) catch return;

    call.uniform_offset = @as(u32, @intCast(ctx.uniforms.items.len));
    const frag = ctx.uniforms.addOne() catch return;
    _ = frag.fromPaint(paint, scissor, 1, fringe, -1, ctx);
    frag.shaderType = @as(f32, @floatFromInt(@intFromEnum(ShaderType.image)));
}

fn renderDelete(uptr: *anyopaque) void {
    const ctx = GLContext.castPtr(uptr);
    ctx.deinit();
}
