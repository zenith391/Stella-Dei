const std = @import("std");
const za = @import("zalgebra");
const Planet = @import("planet.zig").Planet;
const ObjLoader = @import("../ObjLoader.zig");
const Allocator = std.mem.Allocator;
const Vec3 = za.Vec3;

var rabbitMesh: ?ObjLoader.Mesh = null;

pub const Lifeform = struct {
	position: Vec3,
	kind: Kind,

	pub const Kind = enum {
		Rabbit
	};

	pub fn init(allocator: Allocator, position: Vec3, kind: Kind) !Lifeform {
		// init the mesh
		switch (kind) {
			.Rabbit => {
				if (rabbitMesh == null) {
					const mesh = try ObjLoader.readObjFromFile(allocator, "assets/rabbit/rabbit.obj");
					rabbitMesh = mesh;
				}
			}
		}
		return Lifeform { .position = position, .kind = kind };
	}

	pub fn getMesh(self: Lifeform) ObjLoader.Mesh {
		return switch (self.kind) {
			.Rabbit => rabbitMesh.?
		};
	}

	pub fn aiStep(self: Lifeform) void {
		_ = self;
		// TODO
	}
};
