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
			.musicManager = MusicManager.init(allocator)
		};
	}

	pub fn playFromFile(self: *AudioSubsystem, path: [:0]const u8) void {
		if (c.ma_engine_play_sound(self.engine, path, null) != c.MA_SUCCESS) {
			std.log.err("couldn't play sound", .{});
		}
	}

	pub fn playSoundTrack(self: *AudioSubsystem, soundTrack: SoundTrack) void {
		self.musicManager.soundTrack = soundTrack;

		const random = self.musicManager.prng.random();
		self.musicManager.soundTrack.position = random.uintLessThanBiased(usize, soundTrack.items.len);
		self.musicManager.nextMusicTime = std.time.milliTimestamp() + random.intRangeAtMostBiased(i64, 5000, 20000);
	}

	pub fn update(self: *AudioSubsystem) void {
		self.musicManager.update();
	}

	pub fn deinit(self: *AudioSubsystem) void {
		self.musicManager.deinit();
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
	nextMusicTime: i64 = std.math.minInt(i64),
	currentlyPlaying: ?*c.ma_sound = null,
	allocator: Allocator,
	prng: std.rand.DefaultPrng,

	pub fn init(allocator: Allocator) MusicManager {
		return MusicManager {
			.allocator = allocator,
			.prng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.milliTimestamp()))
		};
	}

	pub fn update(self: *MusicManager) void {
		const subsystem = @fieldParentPtr(AudioSubsystem, "musicManager", self);
		if (self.currentlyPlaying) |sound| {
			if (c.ma_sound_at_end(sound) != 0) {
				c.ma_sound_uninit(sound);
				self.allocator.destroy(sound);
				self.currentlyPlaying = null;

				// add a silence moment that can last from 15 to 30 seconds
				const random = self.prng.random();
				self.nextMusicTime = std.time.milliTimestamp() + random.intRangeAtMostBiased(i64, 15000, 30000);
			}
		} else if (std.time.milliTimestamp() >= self.nextMusicTime) { // time for the next music to play
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

	pub fn deinit(self: *MusicManager) void {
		if (self.currentlyPlaying) |sound| {
			c.ma_sound_uninit(sound);
			self.allocator.destroy(sound);
			self.currentlyPlaying = null;
		}
	}
};
