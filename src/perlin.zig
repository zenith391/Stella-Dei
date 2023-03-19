//! Zig port of Ken Perlin's Improved Noise - https://mrl.cs.nyu.edu/~perlin/noise/
const std = @import("std");

fn lerp(t: f32, a: f32, b: f32) f32 {
    std.debug.assert(t >= 0 and t <= 1);
    if (std.debug.runtime_safety and (t < 0 or t > 1)) {
        std.debug.panic("check 0 <= t <= 1 failed, got t={d}", .{t});
    }
    return a * (1 - t) + b * t;
}

/// Performs perlin noise on given X, Y and Z coordinates.
/// Returns a value between -1 and 1.
pub fn p3d(in_x: f32, in_y: f32, in_z: f32) f32 {
    // find unit cube that contains point
    const X: u9 = @truncate(u8, @floatToInt(u32, in_x));
    const Y = @truncate(u8, @floatToInt(u32, in_y));
    const Z = @truncate(u8, @floatToInt(u32, in_z));

    // find relative x,y,z of point in cube
    const x = in_x - @floor(in_x);
    const y = in_y - @floor(in_y);
    const z = in_z - @floor(in_z);

    // compute fade curves for each of x,y,z
    const u = fade(x);
    const v = fade(y);
    const w = fade(z);

    // hash coordinates of the 8 cube corners
    // zig note: cast to u9 so that the two u8 can be added together without overflow
    const A = @as(u9, p[X]) + Y;
    const AA = @as(u9, p[A]) + Z;
    const AB = @as(u9, p[A + 1]) + Z;
    const B = @as(u9, p[X + 1]) + Y;
    const BA = @as(u9, p[B]) + Z;
    const BB = @as(u9, p[B + 1]) + Z;

    // and add blended results from 8 corners of cube
    return lerp(w, lerp(v, lerp(u, grad(p[AA], x, y, z), grad(p[BA], x - 1, y, z)), lerp(u, grad(p[AB], x, y - 1, z), grad(p[BB], x - 1, y - 1, z))), lerp(v, lerp(u, grad(p[AA + 1], x, y, z - 1), grad(p[BA + 1], x - 1, y, z - 1)), lerp(u, grad(p[AB + 1], x, y - 1, z - 1), grad(p[BB + 1], x - 1, y - 1, z - 1))));
}

/// Performs multiple perlin noises (using octaves) on given X, Y and Z coordinates.
/// Returns a value between -1 and 1.
pub fn fbm(x: f32, y: f32, z: f32, octaves: u32) f32 {
    var i: u32 = 0;
    var value: f32 = 0;

    const G = 0.5;
    var f: f32 = 1.0;
    var a: f32 = 1.0;
    while (i < octaves) : (i += 1) {
        value += a * p3d(x * f, y * f, z * f);
        f *= 2.0;
        a *= G;
    }

    return value;
}

pub fn noise(x: f32, y: f32, z: f32) f32 {
    const qX = fbm(x + 0.0, y + 0.0, z + 0.0, 4) + 1;
    const qY = fbm(x + 5.2, y + 1.3, z + 2.5, 4) + 1;
    const qZ = fbm(x + 1.1, y + 5.5, z + 3.2, 4) + 1;
    const c = 1.05;
    return fbm(x + c * qX, y + c * qY, z + c * qZ, 4);
}

fn fade(t: f64) f32 {
    return @floatCast(f32, t * t * t * (t * (t * 6 - 15) + 10));
}

fn grad(hash: u8, x: f32, y: f32, z: f32) f32 {
    // convert lo 4 bits of hash code into 12 gradient directions
    const h = @truncate(u4, hash);
    const u = if (h < 8) x else y;
    const v = if (h < 4) y else if (h == 12 or h == 14) x else z;
    return if (h & 1 == 0) u else -u + if (h & 2 == 0) v else -v;
}

const permutation = [256]u8{ 151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180 };
var p = permutation ** 2;

pub fn setSeed(seed: u64) void {
    var prng = std.rand.DefaultPrng.init(seed);
    const random = prng.random();
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        p[i] = random.int(u8);
        p[i + 256] = random.int(u8);
    }
}
