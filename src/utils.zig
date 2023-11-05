const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const tracy = @import("vendor/tracy.zig");
const Vec3 = za.Vec3;

const icoX = 0.525731112119133606;
const icoZ = 0.850650808352039932;
const icoVertices: []const f32 = &[_]f32{
    -icoX, 0,     icoZ,
    icoX,  0,     icoZ,
    -icoX, 0,     -icoZ,
    icoX,  0,     -icoZ,
    0,     icoZ,  icoX,
    0,     icoZ,  -icoX,
    0,     -icoZ, icoX,
    0,     -icoZ, -icoX,
    icoZ,  icoX,  0,
    -icoZ, icoX,  0,
    icoZ,  -icoX, 0,
    -icoZ, -icoX, 0,
};

const icoIndices: []const gl.GLuint = &[_]gl.GLuint{ 0, 4, 1, 0, 9, 4, 9, 5, 4, 4, 5, 8, 4, 8, 1, 8, 10, 1, 8, 3, 10, 5, 3, 8, 5, 2, 3, 2, 7, 3, 7, 10, 3, 7, 6, 10, 7, 11, 6, 11, 0, 6, 0, 1, 6, 6, 1, 10, 9, 0, 11, 9, 11, 2, 9, 2, 5, 7, 2, 11 };

const IndexPair = struct { first: gl.GLuint, second: gl.GLuint };

pub const IcosphereMesh = struct {
    vao: [8]gl.GLuint,
    vbo: gl.GLuint,
    num_points: usize,
    num_elements: [8]c_int,
    vertices: []const f32,
    indices: []const gl.GLuint,

    const LookupMap = std.AutoHashMap(IndexPair, gl.GLuint);
    fn vertexForEdge(lookup: *LookupMap, vertices: *std.ArrayList(f32), first: gl.GLuint, second: gl.GLuint) !gl.GLuint {
        const a = if (first > second) first else second;
        const b = if (first > second) second else first;

        const pair = IndexPair{ .first = a, .second = b };
        const result = try lookup.getOrPut(pair);
        if (!result.found_existing) {
            result.value_ptr.* = @as(gl.GLuint, @intCast(vertices.items.len / 3));
            const edge0 = Vec3.new(
                vertices.items[a * 3 + 0],
                vertices.items[a * 3 + 1],
                vertices.items[a * 3 + 2],
            );
            const edge1 = Vec3.new(
                vertices.items[b * 3 + 0],
                vertices.items[b * 3 + 1],
                vertices.items[b * 3 + 2],
            );
            const point = edge0.add(edge1).norm();
            try vertices.append(point.x());
            try vertices.append(point.y());
            try vertices.append(point.z());
        }

        return result.value_ptr.*;
    }

    const IndexedMesh = struct { vertices: []const f32, indices: []const gl.GLuint };

    fn subdivide(allocator: std.mem.Allocator, vertices: []const f32, indices: []const gl.GLuint) !IndexedMesh {
        var lookup = LookupMap.init(allocator);
        defer lookup.deinit();
        var result = std.ArrayList(gl.GLuint).init(allocator);
        var verticesList = std.ArrayList(f32).init(allocator);
        try verticesList.appendSlice(vertices);

        var i: usize = 0;
        while (i < indices.len) : (i += 3) {
            var mid: [3]gl.GLuint = undefined;
            var edge: usize = 0;
            while (edge < 3) : (edge += 1) {
                mid[edge] = try vertexForEdge(&lookup, &verticesList, indices[i + edge], indices[i + (edge + 1) % 3]);
            }

            try result.ensureUnusedCapacity(12);
            result.appendAssumeCapacity(indices[i + 0]);
            result.appendAssumeCapacity(mid[0]);
            result.appendAssumeCapacity(mid[2]);

            result.appendAssumeCapacity(indices[i + 1]);
            result.appendAssumeCapacity(mid[1]);
            result.appendAssumeCapacity(mid[0]);

            result.appendAssumeCapacity(indices[i + 2]);
            result.appendAssumeCapacity(mid[2]);
            result.appendAssumeCapacity(mid[1]);

            result.appendAssumeCapacity(mid[0]);
            result.appendAssumeCapacity(mid[1]);
            result.appendAssumeCapacity(mid[2]);
        }

        return IndexedMesh{
            .vertices = try verticesList.toOwnedSlice(),
            .indices = try result.toOwnedSlice(),
        };
    }

    pub fn generate(allocator: std.mem.Allocator, numSubdivisions: usize, octants: bool) !IcosphereMesh {
        const zone = tracy.ZoneN(@src(), "Generate icosphere");
        defer zone.End();

        var vao: [8]gl.GLuint = undefined;
        gl.genVertexArrays(if (octants) 8 else 1, &vao);
        var vbo: gl.GLuint = undefined;
        gl.genBuffers(1, &vbo);
        var ebo: [8]gl.GLuint = undefined;
        gl.genBuffers(if (octants) 8 else 1, &ebo);

        std.debug.assert(vao[0] != 0xaaaaaaaa);
        std.debug.assert(vbo != 0xaaaaaaaa);
        std.debug.assert(ebo[0] != 0xaaaaaaaa);

        var subdivided = IndexedMesh{ .vertices = icoVertices, .indices = icoIndices };
        {
            var i: usize = 0;
            while (i < numSubdivisions) : (i += 1) {
                const oldSubdivided = subdivided;
                const vert = subdivided.vertices;
                const indc = subdivided.indices;
                subdivided = try subdivide(allocator, vert, indc);

                if (i > 0) {
                    allocator.free(oldSubdivided.vertices);
                    allocator.free(oldSubdivided.indices);
                }
            }
        }

        // The sign (1 or -1) of XYZ for a given octant
        const octantsSign = [8]Vec3{
            Vec3.new(1, 1, 1), // top right    Z+
            Vec3.new(-1, 1, 1), // top left     Z+
            Vec3.new(1, -1, 1), // bottom right Z+
            Vec3.new(-1, -1, 1), // bottom left  Z+
            Vec3.new(1, 1, -1), // top right    Z-
            Vec3.new(-1, 1, -1), // top left     Z-
            Vec3.new(1, -1, -1), // bottom right Z-
            Vec3.new(-1, -1, -1), // bottom left  Z-
        };
        var numElements: [8]c_int = undefined;

        if (octants) {
            var i: usize = 0;
            while (i < 8) : (i += 1) {
                const octant = octantsSign[i];
                gl.bindVertexArray(vao[i]);
                gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
                gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo[i]);

                // TODO: add triangles not indices!!!
                var indicesList = std.ArrayList(gl.GLuint).init(allocator);
                var triangleIdx: c_uint = 0;
                while (triangleIdx < subdivided.indices.len) : (triangleIdx += 3) {
                    const A = Vec3.fromSlice(subdivided.vertices[subdivided.indices[triangleIdx] * 3 ..]);
                    const B = Vec3.fromSlice(subdivided.vertices[subdivided.indices[triangleIdx + 1] * 3 ..]);
                    const C = Vec3.fromSlice(subdivided.vertices[subdivided.indices[triangleIdx + 2] * 3 ..]);
                    // Barycenter of the triangle
                    const G = A.add(B).add(C).scale(1.0 / 3.0);

                    if (@reduce(.And, (G.data >= Vec3.zero().data) == (octant.data >= Vec3.zero().data))) {
                        try indicesList.append(subdivided.indices[triangleIdx]);
                        try indicesList.append(subdivided.indices[triangleIdx + 1]);
                        try indicesList.append(subdivided.indices[triangleIdx + 2]);
                    }
                }
                const indices = try indicesList.toOwnedSlice();
                defer allocator.free(indices);

                numElements[i] = @as(c_int, @intCast(indices.len));

                gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @as(isize, @intCast(indices.len * @sizeOf(c_uint))), indices.ptr, gl.STATIC_DRAW);
            }
        } else {
            gl.bindVertexArray(vao[0]);
            gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo[0]);
            gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @as(isize, @intCast(subdivided.indices.len * @sizeOf(c_uint))), subdivided.indices.ptr, gl.STATIC_DRAW);
        }

        return IcosphereMesh{
            .vao = vao,
            .vbo = vbo,
            .num_points = subdivided.vertices.len / 3,
            .num_elements = numElements,
            .indices = subdivided.indices,
            .vertices = subdivided.vertices,
        };
    }

    pub fn deinit(self: IcosphereMesh, allocator: std.mem.Allocator) void {
        allocator.free(self.indices);
        allocator.free(self.vertices);
    }
};

pub const CubeMesh = struct {
    const vertices = [36 * 3]f32{
        -0.5, -0.5, -0.5,
        0.5,  -0.5, -0.5,
        0.5,  0.5,  -0.5,
        0.5,  0.5,  -0.5,
        -0.5, 0.5,  -0.5,
        -0.5, -0.5, -0.5,

        -0.5, -0.5, 0.5,
        0.5,  -0.5, 0.5,
        0.5,  0.5,  0.5,
        0.5,  0.5,  0.5,
        -0.5, 0.5,  0.5,
        -0.5, -0.5, 0.5,

        -0.5, 0.5,  0.5,
        -0.5, 0.5,  -0.5,
        -0.5, -0.5, -0.5,
        -0.5, -0.5, -0.5,
        -0.5, -0.5, 0.5,
        -0.5, 0.5,  0.5,

        0.5,  0.5,  0.5,
        0.5,  0.5,  -0.5,
        0.5,  -0.5, -0.5,
        0.5,  -0.5, -0.5,
        0.5,  -0.5, 0.5,
        0.5,  0.5,  0.5,

        -0.5, -0.5, -0.5,
        0.5,  -0.5, -0.5,
        0.5,  -0.5, 0.5,
        0.5,  -0.5, 0.5,
        -0.5, -0.5, 0.5,
        -0.5, -0.5, -0.5,

        -0.5, 0.5,  -0.5,
        0.5,  0.5,  -0.5,
        0.5,  0.5,  0.5,
        0.5,  0.5,  0.5,
        -0.5, 0.5,  0.5,
        -0.5, 0.5,  -0.5,
    };

    var cube_vao: ?gl.GLuint = null;

    pub fn getVAO() gl.GLuint {
        if (cube_vao == null) {
            var vao: gl.GLuint = undefined;
            gl.genVertexArrays(1, &vao);
            var vbo: gl.GLuint = undefined;
            gl.genBuffers(1, &vbo);

            gl.bindVertexArray(vao);
            gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
            gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @intCast(vertices.len * @sizeOf(f32))), &vertices, gl.STATIC_DRAW);
            gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), @as(?*anyopaque, @ptrFromInt(0 * @sizeOf(f32)))); // position
            gl.enableVertexAttribArray(0);
            cube_vao = vao;
        }
        return cube_vao.?;
    }
};

/// Wavelength must be a number expressed in nanometers
/// The returned color is in the RGB color space.
/// It doesn't account for HDR or tone mapping.
pub fn getWavelengthColor(wavelength: f32) Vec3 {
    const gamma: f32 = 0.80;

    var red: f32 = 0;
    var green: f32 = 0;
    var blue: f32 = 0;

    // Refactor
    if (wavelength >= 380 and wavelength < 510) {
        red = @max(0, -(wavelength - 440) / (440 - 380));
        green = std.math.clamp((wavelength - 440) / (490 - 440), 0, 1);
        blue = std.math.clamp(-(wavelength - 510) / (510 - 490), 0, 1);
    } else if (wavelength >= 510) {
        red = std.math.clamp((wavelength - 510) / (580 - 510), 0, 1);
        green = std.math.clamp(-(wavelength - 645) / (645 - 580), 0, 1);
        blue = 0.0;
    }

    // Let the intensity fall off near the vision limits
    var factor: f32 = 1;
    if (wavelength >= 380 and wavelength < 420) {
        factor = 0.3 + 0.7 * (wavelength - 380) / (420 - 380);
    } else if (wavelength >= 420 and wavelength < 701) {
        factor = 1;
    } else if (wavelength < 781) {
        factor = 0.3 + 0.7 * (780 - wavelength) / (780 - 700);
    } else {
        factor = 0;
    }

    red = std.math.pow(f32, red * factor, gamma);
    green = std.math.pow(f32, green * factor, gamma);
    blue = std.math.pow(f32, blue * factor, gamma);

    return Vec3.new(red, green, blue);
}
