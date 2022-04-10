const za = @import("zalgebra");
const Planet = @import("planet.zig").Planet;
const Vec3 = za.Vec3;

pub const Lifeform = struct {
	position: Vec3,

	pub fn init(position: Vec3) Lifeform {
		return Lifeform { .position = position };
	}

	pub fn aiStep() void {

	}
};
