const std = @import("std");
const za = @import("zalgebra");
const Planet = @import("planet.zig").Planet;
const ObjLoader = @import("../ObjLoader.zig");
const Allocator = std.mem.Allocator;
const Vec3 = za.Vec3;

var rabbitMesh: ?ObjLoader.Mesh = null;

pub const Lifeform = struct {
	position: Vec3,
	velocity: Vec3 = Vec3.zero(),
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

	pub fn aiStep(self: *Lifeform, planet: *Planet) void {
		self.position.data[1] += 5;
		self.position = self.position.add(self.velocity);
		const pointIdx = planet.getNearestPointTo(self.position);
		const point = planet.transformedPoints[pointIdx];
		if (self.position.length() < point.length()) {
			self.position = self.position.norm().scale(point.length());
			self.velocity = Vec3.zero();
		} else {
			//const baseLength = self.position.length();
			//self.position = self.position.norm().scale(baseLength-1);
			// TODO: accurate gravity
			self.velocity = self.velocity.add(
				self.position.norm().negate() // towards the planet
			);
		}
		
		// Rabbits die at 60°C
		if (planet.temperature[pointIdx] > 273.15 + 60.0) {
			const index = blk: {
				for (planet.lifeforms.items) |*lifeform, idx| {
					if (lifeform == self) break :blk idx;
				}
				unreachable;
			};

			_ = planet.lifeforms.swapRemove(index);
		}
	}
};
