const std = @import("std");
const za = @import("zalgebra");
const Planet = @import("planet.zig").Planet;
const ObjLoader = @import("../ObjLoader.zig");
const Allocator = std.mem.Allocator;
const Vec3 = za.Vec3;

var rabbitMesh: ?ObjLoader.Mesh = null;

const Gender = enum {
	Male, Female
};

const Genome = struct {
	gender: Gender = .Male,
};

pub const Lifeform = struct {
	position: Vec3,
	velocity: Vec3 = Vec3.zero(),
	kind: Kind,
	state: State = .wander,
	/// Game time at which the lifeform was born
	timeBorn: f64,
	prng: std.rand.DefaultPrng,
	/// The minimum bar for a given rabbit's sexual attractiveness
	/// This goes up the more there are attemps at mating
	/// This goes down naturally over time (although this has a
	/// minimum depending on genome)
	sexualCriteria: f32 = 0.1,
	reproductionCooldown: f32 = 0,
	genome: Genome = .{},
	/// Opposite of hunger, goes down gradually.
	/// When it reaches 0, the lifeform dies.
	satiety: f32 = 100,

	pub const Kind = enum {
		Rabbit
	};

	pub const State = union(enum) {
		wander: void,
		go_to_point: Vec3,
		gestation: struct {
			/// Game time at which the lifeform started being 'pregnant'
			since: f64
		},

		fn goToPoint(planet: *const Planet, idx: usize) State {
			// TODO, add some rng to the final position
			const pos = planet.transformedPoints[idx];
			return State {
				.go_to_point = pos
			};
		}
	};

	pub fn initMeshes(allocator: Allocator) !void {
		if (rabbitMesh == null) {
			rabbitMesh = try ObjLoader.readObjFromFile(allocator, "assets/rabbit/rabbit.obj");
		}
	}

	pub fn init(position: Vec3, kind: Kind, gameTime: f64) Lifeform {
		return Lifeform {
			.position = position,
			.kind = kind,
			.prng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.milliTimestamp())),
			.timeBorn = gameTime
		};
	}

	pub fn getMesh(self: Lifeform) ObjLoader.Mesh {
		return switch (self.kind) {
			.Rabbit => rabbitMesh.?
		};
	}

	/// Duration of gestations in in-game seconds
	const GESTATION_DURATION: f64 = 86400; // 1 day
	const SEXUAL_MATURITY_AGE: f64 = 86400 / 2; // 12 hours

	pub fn aiStep(self: *Lifeform, planet: *Planet, options: Planet.SimulationOptions) void {
		const pointIdx = planet.getNearestPointTo(self.position);
		const point = planet.transformedPoints[pointIdx];
		const random = self.prng.random();
		const dt = options.dt * options.timeScale;
		self.reproductionCooldown = std.math.max(0, self.reproductionCooldown - dt);
		self.satiety = std.math.max(0, self.satiety - dt * 0.001);

		const pointTemperature = planet.temperature[pointIdx];

		const age = options.gameTime - self.timeBorn;
		const isInDeepWater = planet.waterMass[pointIdx] > 1 and pointTemperature > 273.15;
		const isFrying = pointTemperature > 273.15 + 60.0;
		const isStarving = self.satiety < 10;
		const isTooOld = age > 10 * 86400;
		var shouldDie: bool = isInDeepWater or isFrying or isStarving or isTooOld;

		if (self.sexualCriteria > 0.3) {
			// lowers by a few every in-game second
			self.sexualCriteria -= 0.000001 * options.timeScale;
			self.sexualCriteria = std.math.max(0.3, self.sexualCriteria);
		}

		switch (self.state) {
			.wander => {
				if (self.satiety < 80) {
					if (planet.vegetation[pointIdx] > 0.2) {
						// eat
						const neededToEat = (100.0 - self.satiety) / 100.0;
						const eaten = std.math.min(planet.vegetation[pointIdx], neededToEat);
						planet.vegetation[pointIdx] -= eaten;
						self.satiety += eaten * 100.0;
						std.log.info("rabbit ate {d} veggie level", .{ eaten });
					} else {
						// TODO: search for food
						std.log.info("OH NO! THERE'S NO FOOD", .{});
					}
				} else if (pointTemperature > 273.15 + 30.0) { // Above 30°C
					// Try to go to a colder point
					var coldestPointIdx: usize = pointIdx;
					var coldestTemperature: f32 = pointTemperature;
					for (planet.getNeighbours(pointIdx)) |neighbourIdx| {
						const isInWater = planet.waterMass[neighbourIdx] > 0.1 and planet.temperature[neighbourIdx] > 273.15;
						if (planet.temperature[neighbourIdx] + random.float(f32)*1 < coldestTemperature and !isInWater) {
							coldestPointIdx = neighbourIdx;
							coldestTemperature = planet.temperature[neighbourIdx];
						}
					}
					self.state = State.goToPoint(planet, coldestPointIdx);
				} else if (pointTemperature < 273.15 + 5.0) { // Below 5°C
					// Try to go to an hotter point
					var hottestPointIdx: usize = pointIdx;
					var hottestTemperature: f32 = pointTemperature;
					for (planet.getNeighbours(pointIdx)) |neighbourIdx| {
						const isInWater = planet.waterMass[neighbourIdx] > 0.1 and planet.temperature[neighbourIdx] > 273.15;
						if (planet.temperature[neighbourIdx] - random.float(f32)*1 > hottestTemperature and !isInWater) {
							hottestPointIdx = neighbourIdx;
							hottestTemperature = planet.temperature[neighbourIdx];
						}
					}
					self.state = State.goToPoint(planet, hottestPointIdx);
				} else {
					var seekingPartner = false;
					for (planet.lifeforms.items) |*other| {
						// Avoid choosing self as a partner
						if (other != self and self.reproductionCooldown == 0) {
							const distance = other.position.distance(self.position);
							if (distance < 100 and age >= SEXUAL_MATURITY_AGE) {
								// TODO: have sexual attractivity depend partially on a gene
								const sexualAttractivity = 0.4 + random.float(f32) * 0.1;
								if (sexualAttractivity >= other.sexualCriteria) {
									const number = random.intRangeLessThanBiased(u8, 0, 100);
									std.log.info("try {}", .{ number });
									if (number == 0) { // 1/100 chance
										// have a baby if it's not already pregnant
										if (other.state != .gestation) {
											std.log.info("a rabbit got pregnant", .{});
											other.state = .{ .gestation = .{
												.since = options.gameTime
											}};
										}
									} else {
										// The other gets more fed up by the attempts
										other.sexualCriteria += 0.05;
									}
								}
								self.reproductionCooldown = 3600;
							} else if (distance < 400 and other.sexualCriteria < 0.45) {
								// lookup the partner
								self.state = .{ .go_to_point = other.position };
								seekingPartner = true;
							}
						}
					}

					if (!seekingPartner) {
						// If the lifeform hasn't found any partner to mate with,
						// just wander around to one of the current point's neighbours
						const neighbours = planet.getNeighbours(pointIdx);
						var attempts: usize = 1;
						var number = random.intRangeLessThanBiased(u8, 0, 6);
						while (planet.waterMass[neighbours[number]] >= 0.1) {
							if (attempts == 6) break;
							number = random.intRangeLessThanBiased(u8, 0, 6);
							attempts += 1;
						}
						self.state = State.goToPoint(planet, neighbours[number]);
					}
				}
			},
			.go_to_point => |target| {
				const direction = target.sub(point);
				self.velocity = direction.norm().scale(0.02); // 3km/frame
				//std.log.info("(dist={d}) go by {}", .{ direction.dot(direction), direction });
				if (direction.dot(direction) < 1000) {
					self.state = .wander;
				}
			},
			.gestation => |info| {
				if (options.gameTime > info.since + GESTATION_DURATION) {
					std.log.info("a rabbit got a baby", .{});

					const number = random.intRangeLessThanBiased(u8, 0, 6);
					if (number == 0) { // 1/6 chance to die
						shouldDie = true;
					}
					self.state = .wander;
					self.sexualCriteria = 25;
					
					const lifeform = Lifeform.init(point, self.kind, options.gameTime);
					planet.addLifeform(lifeform) catch {
						// TODO?
					};
					// Must return as the array list may have expanded, in which case
					// the 'self' pointer is now invalid!
					return;
				}
			}
		}
		if (self.position.length() < point.length()) {
			self.position = self.position.norm().scale(point.length());
			self.velocity = Vec3.zero();
		} else {
			// TODO: accurate gravity
			self.velocity = self.velocity.add(
				self.position.norm().negate().scale(0.015) // towards the planet
			);
		}
		self.position = self.position.add(self.velocity.scale(dt));

		if (shouldDie) {
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
