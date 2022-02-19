const std = @import("std");
const c = @cImport({
	@cInclude("miniaudio.h");
});

pub const AudioSubsystem = struct {
	engine: *c.ma_engine,

	pub fn init(allocator: std.mem.Allocator) !AudioSubsystem {
		var engine = try allocator.create(c.ma_engine);
		if (c.ma_engine_init(null, engine) != c.MA_SUCCESS) {
			return error.AudioInitError;
		}

		return AudioSubsystem {
			.engine = engine
		};
	}

	pub fn playFromFile(self: *AudioSubsystem, path: [:0]const u8) void {
		c.ma_engine_play_sound(self.engine, path, null);
	}

	pub fn deinit(self: *AudioSubsystem) void {
		c.ma_engine_uninit(self.engine);
	}

};
