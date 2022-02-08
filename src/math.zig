const std = @import("std");
const za = @import("zalgebra");

const Allocator = std.mem.Allocator;
const Vec3 = za.Vec3;

const Triangle = struct {
	vertex1: Vec3,
	vertex2: Vec3,
	vertex3: Vec3,
	center: Vec3,
	radius: f32,
	
	pub fn init(vtx1: Vec3, vtx2: Vec3, vtx3: Vec3) Triangle {
		const x1 = vtx1.x();
		const y1 = vtx1.y();
		const z1 = vtx1.z();

		const x2 = vtx2.x();
		const y2 = vtx2.y();
		const z2 = vtx2.z();

		const x3 = vtx3.x();
		const y3 = vtx3.y();
		const z3 = vtx3.z();

		const a = vtx3.distance(vtx2);
		const b = vtx1.distance(vtx3);
		const c = vtx2.distance(vtx1);

		const center = vtx1.scale(a/(a+b+c))
			.add(vtx2.scale(b/(a+b+c)))
			.add(vtx3.scale(c/(a+b+c)));
		
		const radius = std.math.sqrt(
			std.math.abs(vtx1.x() - center.x()) * std.math.abs(vtx1.x() - center.x()) +
			std.math.abs(vtx1.y() - center.y()) * std.math.abs(vtx1.y() - center.y()) +
			std.math.abs(vtx1.z() - center.z()) * std.math.abs(vtx1.z() - center.z())
		);

		return Triangle {
			.vertex1 = vtx1,
			.vertex2 = vtx2,
			.vertex3 = vtx3,
			.center = center,
			.radius = radius,
		};
	}

	pub fn isInCircumsphere(self: Triangle, point: Vec3) bool {
		return point.distance(self.center) <= self.radius;
	}
};

// Tri-dimensional Delauney triangulation
pub fn delauneyTriangulation(allocator: Allocator, points: []const Vec3) !void {
	var triangulation = std.ArrayList(Triangle).init(allocator);

	for (points) |point| {
		var badTrianglesIdx = std.ArrayList(usize).init(allocator);
		defer badTrianglesIdx.deinit();
		for (triangulation.items) |triangle, idx| {
			if (triangle.isInCircumsphere(point)) {
				try badTrianglesIdx.append(idx);
			}
		}

		for (badTriangles.items) |idx| {
			// TODO: solve some cases
			triangulation.swapRemove(idx);
		}
	}
}
