const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @cImport({
	@cInclude("miniaudio.h");
});

pub const AudioSubsystem = struct {
	engine: *c.ma_engine,
	allocator: Allocator,
	musicManager: MusicManager,

	pub fn init(allocator: Allocator) !AudioSubsystem {
		const engine = try allocator.create(c.ma_engine);
		if (c.ma_engine_init(null, engine) != c.MA_SUCCESS) {
			return error.AudioInitError;
		}

		return AudioSubsystem {
			.engine = engine,
			.allocator = allocator,
			.musicManager = .{ .allocator = allocator }
		};
	}

	pub fn playFromFile(self: *AudioSubsystem, path: [:0]const u8) void {
		if (c.ma_engine_play_sound(self.engine, path, null) != c.MA_SUCCESS) {
			std.log.err("couldn't play sound", .{});
		}
	}

	pub fn playSoundTrack(self: *AudioSubsystem, soundTrack: SoundTrack) void {
		self.musicManager.soundTrack = soundTrack;
	}

	pub fn update(self: *AudioSubsystem) void {
		self.musicManager.update();
	}

	pub fn deinit(self: *AudioSubsystem) void {
		c.ma_engine_uninit(self.engine);
		self.allocator.destroy(self.engine);
	}

};

pub const SoundTrack = struct {
	items: []const [:0]const u8,
	position: usize = 0,

	const silence = SoundTrack { .items = &.{} };

	pub fn getNextItem(self: SoundTrack) ?[:0]const u8 {
		if (self.items.len == 0) return null;
		return self.items[self.position];
	}

	pub fn increment(self: *SoundTrack) void {
		if (self.items.len > 0) {
			self.position = (self.position + 1) % self.items.len;
		}
	}
};

pub const MusicManager = struct {
	soundTrack: SoundTrack = SoundTrack.silence,
	currentlyPlaying: ?*c.ma_sound = null,
	allocator: Allocator,

	pub fn update(self: *MusicManager) void {
		const subsystem = @fieldParentPtr(AudioSubsystem, "musicManager", self);
		if (self.currentlyPlaying) |sound| {
			if (c.ma_sound_at_end(sound) != 0) {
				c.ma_sound_uninit(sound);
				self.allocator.destroy(sound);
				self.currentlyPlaying = null;
			}
		} else {
			if (self.soundTrack.getNextItem()) |nextItem| {
				const sound = self.allocator.create(c.ma_sound) catch return;
				if (c.ma_sound_init_from_file(subsystem.engine, nextItem, c.MA_SOUND_FLAG_ASYNC |
					c.MA_SOUND_FLAG_NO_PITCH | c.MA_SOUND_FLAG_NO_SPATIALIZATION, null, null, sound) != c.MA_SUCCESS) {
					std.log.scoped(.audio).warn("Could not load music '{s}'", .{ nextItem });
					return;
				}
				c.ma_sound_set_volume(sound, 0.4);
				if (c.ma_sound_start(sound) != c.MA_SUCCESS) {
					std.log.scoped(.audio).warn("Could not start music '{s}'", .{ nextItem });
				}
				self.currentlyPlaying = sound;
				self.soundTrack.increment();
			}
		}

	}
};
