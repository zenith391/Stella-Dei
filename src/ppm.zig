const std = @import("std");
const Allocator = std.mem.Allocator;

const Pixel = struct {
    r: u8,
    g: u8,
    b: u8
};

pub const Image = struct {
    width: usize,
    height: usize,
    data: []Pixel,
    allocator: *Allocator,

    pub fn generate(allocator: *Allocator, width: usize, height: usize, generator: fn(x: f32, y: f32) f32) !Image {
        var data = try allocator.alloc(Pixel, width * height);

        var x: usize = 0;
        while (x < width) : (x += 1) {
            var y: usize = 0;
            while (y < height) : (y += 1) {
                const octaves = 5;

                var i: usize = 0;
                var p: f32 = 0;
                while (i < octaves) : (i += 1) {
                    const pow = std.math.pow(f32, 2, @intToFloat(f32, i));
                    const res = generator(@intToFloat(f32, x) / pow, @intToFloat(f32, y) / pow);
                    p += res / pow;
                }
                p += 1;
                p /= 2;
                if (p < 0) p = 0;
                if (p > 1) p = 1;
                data[x + y * width] = .{
                    .r = @floatToInt(u8, p * 255),
                    .g = @floatToInt(u8, p * 255),
                    .b = @floatToInt(u8, p * 255),
                };
            }
        }

        return Image { .width = width, .height = height, .data = data, .allocator = allocator };
    }

    pub fn deinit(self: *const Image) void {
        self.allocator.free(self.data);
    }
};

pub fn write(path: []const u8, img: Image) !void {
    const file = try std.fs.cwd().createFile(path, .{ });
    defer file.close();
    var bufferedWriter = std.io.bufferedWriter(file.writer());
    const writer = bufferedWriter.writer();

    try writer.print("P3\n{d} {d}\n255\n", .{img.width, img.height});

    var y: usize = 0;
    while (y < img.height) : (y += 1) {
        var x: usize = 0;
        while (x < img.width) : (x += 1) {
            const pixel = img.data[x + y * img.width];
            try writer.print("{d} {d} {d}\n", .{
                pixel.r,
                pixel.g,
                pixel.b
            });
        }
    }
}
