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
	prng: std.rand.DefaultPrng,

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
		return Lifeform { .position = position, .kind = kind, .prng = std.rand.DefaultPrng.init(246) };
	}

	pub fn getMesh(self: Lifeform) ObjLoader.Mesh {
		return switch (self.kind) {
			.Rabbit => rabbitMesh.?
		};
	}

	pub fn aiStep(self: *Lifeform, planet: *Planet) void {
		const pointIdx = planet.getNearestPointTo(self.position);
		const point = planet.transformedPoints[pointIdx];
		const random = self.prng.random();

		if (planet.temperature[pointIdx] > 273.15 + 30.0) { // Above 30°C
			// Try to go to a colder point
			var coldestPointIdx: usize = pointIdx;
			var coldestTemperature: f32 = planet.temperature[pointIdx];
			for (planet.getNeighbours(pointIdx)) |neighbourIdx| {
				const isInWater = planet.waterElevation[neighbourIdx] > 0.1 and planet.temperature[neighbourIdx] > 273.15;
				if (planet.temperature[neighbourIdx] + random.float(f32)*1 < coldestTemperature and !isInWater) {
					coldestPointIdx = neighbourIdx;
					coldestTemperature = planet.temperature[neighbourIdx];
				}
			}
			const targetPoint = planet.transformedPoints[coldestPointIdx];
			self.velocity = targetPoint.sub(point).scale(0.02);
		} else if (planet.temperature[pointIdx] < 273.15 + 0.0) { // Below 0°C
			// Try to go to an hotter point
			var hottestPointIdx: usize = pointIdx;
			var hottestTemperature: f32 = planet.temperature[pointIdx];
			for (planet.getNeighbours(pointIdx)) |neighbourIdx| {
				const isInWater = planet.waterElevation[neighbourIdx] > 0.1 and planet.temperature[neighbourIdx] > 273.15;
				if (planet.temperature[neighbourIdx] - random.float(f32)*1 > hottestTemperature and !isInWater) {
					hottestPointIdx = neighbourIdx;
					hottestTemperature = planet.temperature[neighbourIdx];
				}
			}
			const targetPoint = planet.transformedPoints[hottestPointIdx];
			self.velocity = targetPoint.sub(point).scale(0.02);
		}
		
		self.position = self.position.add(self.velocity);

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
		

		const isInDeepWater = planet.waterElevation[neighbourIdx] > 1 and planet.temperature[neighbourIdx] > 273.15;
		// Rabbits die at 60°C or when drowning
		if (planet.temperature[pointIdx] > 273.15 + 60.0 or isInDeepWater) {
			const index = blk: {
				for (planet.lifeforms.items) |*lifeform, idx| {
					if (lifeform == self) break :blk idx;
				}
				// already removed???
				return;
			};

			// we're iterating so avoid a swapRemove
			_ = planet.lifeforms.orderedRemove(index);
		}
	}
};
