const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;

const ObjError = error{
    /// The OBJ loader currently can't triangulate quads, so just throw an error
    TooManyVerticesPerFace,
};

const Element = struct { posIdx: usize, texIdx: usize, normalIdx: usize };

pub const Mesh = struct {
    vao: gl.GLuint,
    vbo: gl.GLuint,
    numTriangles: c_int,

    pub fn create(data: []const f32) Mesh {
        var vao: gl.GLuint = undefined;
        gl.genVertexArrays(1, &vao);
        var vbo: gl.GLuint = undefined;
        gl.genBuffers(1, &vbo);

        gl.bindVertexArray(vao);
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);

        gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @bitCast(data.len * @sizeOf(f32))), data.ptr, gl.STATIC_DRAW);
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @as(?*anyopaque, @ptrFromInt(0 * @sizeOf(f32)))); // position
        gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @as(?*anyopaque, @ptrFromInt(3 * @sizeOf(f32)))); // normal
        gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @as(?*anyopaque, @ptrFromInt(6 * @sizeOf(f32)))); // texture coordinates
        gl.enableVertexAttribArray(0);
        gl.enableVertexAttribArray(1);
        gl.enableVertexAttribArray(2);

        return Mesh{ .vao = vao, .vbo = vbo, .numTriangles = @as(c_int, @intCast(data.len / 8)) };
    }
};

pub fn readObj(allocator: Allocator, reader: anytype) !Mesh {
    var vertices = ArrayList(Vec3).init(allocator);
    var normals = ArrayList(Vec3).init(allocator);
    var texCoords = ArrayList(Vec2).init(allocator);
    var elements = ArrayList(Element).init(allocator);

    defer vertices.deinit();
    defer elements.deinit();
    defer normals.deinit();
    defer texCoords.deinit();

    const text = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(text);
    var linesSplit = std.mem.split(u8, text, "\n");

    while (true) {
        const line = if (linesSplit.next()) |s| s else break;
        var split = std.mem.split(u8, line, " ");
        const command = split.next().?;
        if (std.mem.eql(u8, command, "v")) { // vertex (position)
            const xStr = split.next().?;
            const yStr = split.next().?;
            const zStr = split.next().?;
            //var wStr = "1.0";
            //if (split.next()) |w| {
            //  wStr = w;
            //}

            const x = try std.fmt.parseFloat(f32, xStr);
            const y = try std.fmt.parseFloat(f32, yStr);
            const z = try std.fmt.parseFloat(f32, zStr);
            try vertices.append(Vec3.new(x, y, z));
        } else if (std.mem.eql(u8, command, "vt")) { // vertex (texture coordinate)
            const uStr = split.next().?;
            const vStr = split.next().?;
            //const wStr = split.next().?;

            const u = try std.fmt.parseFloat(f32, uStr);
            const v = try std.fmt.parseFloat(f32, vStr);
            //const w = try std.fmt.parseFloat(f32, wStr);
            try texCoords.append(Vec2.new(u, v));
        } else if (std.mem.eql(u8, command, "vn")) { // vertex (normal)
            const xStr = split.next().?;
            const yStr = split.next().?;
            const zStr = split.next().?;

            const x = try std.fmt.parseFloat(f32, xStr);
            const y = try std.fmt.parseFloat(f32, yStr);
            const z = try std.fmt.parseFloat(f32, zStr);
            try normals.append(Vec3.new(x, y, z));
        } else if (std.mem.eql(u8, command, "f")) { // face
            var faceVertices: usize = 0;
            while (true) {
                faceVertices += 1;
                if (split.next()) |vertex| {
                    if (faceVertices == 4) {
                        return ObjError.TooManyVerticesPerFace;
                    }
                    var faceSplit = std.mem.split(u8, vertex, "/");
                    var posIdx = try std.fmt.parseInt(i32, faceSplit.next().?, 10);
                    const texIdxStr = faceSplit.next().?;
                    var texIdx = if (texIdxStr.len == 0) 0 else try std.fmt.parseInt(i32, texIdxStr, 10);
                    const normalIdxStr = faceSplit.next();
                    var normalIdx = if (normalIdxStr) |str| try std.fmt.parseInt(i32, str, 10) else 0;
                    if (normalIdx < 1) {
                        normalIdx = 1; // TODO
                    }
                    if (texIdx < 1) {
                        texIdx = 1; // TODO
                    }
                    if (posIdx < 1) {
                        posIdx = 1; // TODO
                    }
                    try elements.append(.{
                        .posIdx = @as(usize, @intCast(posIdx - 1)),
                        .texIdx = @as(usize, @intCast(texIdx - 1)),
                        .normalIdx = @as(usize, @intCast(normalIdx - 1)),
                    });
                } else {
                    break;
                }
            }
        } else {
            //std.debug.warn("Unknown OBJ command: {}\n", .{command});
        }
    }

    var final = try allocator.alloc(f32, elements.items.len * 8);
    defer allocator.free(final);
    var i: usize = 0;
    for (elements.items) |f| {
        const v = vertices.items[f.posIdx];
        const t = if (texCoords.items.len == 0) Vec2.zero() else texCoords.items[f.texIdx];
        const n = if (normals.items.len == 0) Vec3.zero() else normals.items[f.normalIdx];
        // position
        final[i] = v.x();
        final[i + 1] = v.y();
        final[i + 2] = v.z();
        // normal
        final[i + 3] = n.x();
        final[i + 4] = n.y();
        final[i + 5] = n.z();
        // texture coordinate
        final[i + 6] = t.x();
        final[i + 7] = t.y();
        i = i + 8;
    }

    return Mesh.create(final); // TODO simplify
}

pub fn readObjFromFile(allocator: Allocator, path: []const u8) !Mesh {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    const reader = buffered.reader();
    return try readObj(allocator, reader);
}
