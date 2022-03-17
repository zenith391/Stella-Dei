const std = @import("std");

const GridPoint = struct {
	/// From 0 to 255 inclusive
	x: f32,
	/// From 0 to 255 inclusive
	y: f32
};

fn lerp(a: f32, b: f32, t: f32) f32 {
	if (t > 1 or t < 0) std.debug.panic("invalid t value: {d}", .{ t });
	return a * (1 - t) + b * t;
}

fn s(x: f32) f32 {
	return 3 * x * x - 2 * x * x * x;
}

fn dotGridGradient(p: [256]GridPoint, ix: i32, iy: i32, x: f32, y: f32) f32 {
	const dx = x - @intToFloat(f32, ix);
	const dy = y - @intToFloat(f32, iy);

	var point = p[@intCast(usize, iy * 16 + ix)];
	const gr = std.math.sqrt(point.x * point.x + point.y * point.y);
	point.x /= gr;
	point.y /= gr;

	return (dx * point.x + dy * point.y);
}

/// Performs perlin noise on given X and Y coordinates.
/// Returns a value between -1 and 1.
pub fn p2d(in_x: f32, in_y: f32) f32 {
	var x = @rem(std.math.fabs(in_x), 15);
	var y = @rem(std.math.fabs(in_y), 15);

	const x0 = @floatToInt(i32, @floor(x));
	const x1 = x0 + 1;
	const y0 = @floatToInt(i32, @floor(y));
	const y1 = y0 + 1;

	const sx = s(x - @intToFloat(f32, x0));
	const sy = s(y - @intToFloat(f32, y0));

	const seed = @intCast(u64, std.math.absInt(x0) catch unreachable) / 16 *% 48713354 +%
		@intCast(u64, std.math.absInt(y0) catch unreachable) / 16 *% 23481520;

	var permutations: [256]GridPoint = undefined;
	var random = std.rand.Xoshiro256.init(seed);
	const rand = random.random();

	for (permutations) |*perm| {
		perm.* = .{
			.x = rand.float(f32) * 2 - 1,
			.y = rand.float(f32) * 2 - 1
		};
	}

	const ix0 = lerp(
		dotGridGradient(permutations, x0, y0, x, y),
		dotGridGradient(permutations, x1, y0, x, y),
		sx
	);

	const ix1 = lerp(
		dotGridGradient(permutations, x0, y1, x, y),
		dotGridGradient(permutations, x1, y1, x, y),
		sx
	);

	return lerp(ix0, ix1, sy);
}

/// Performs multiple perlin noises (using octaves) on given X and Y coordinates.
/// Returns a value between -1 and 1.
pub fn p2do(x: f32, y: f32, octaves: u32) f32 {
	var i: u32 = 0;
    var p: f32 = 0;
    while (i < octaves) : (i += 1) {
        const pow = std.math.pow(f32, 2, @intToFloat(f32, i));
        const res = p2d(x * pow, y * pow);
        p += res / pow;
    }

    return p;
}