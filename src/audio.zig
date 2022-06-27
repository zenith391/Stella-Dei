const std = @import("std");
const tracy = @import("vendor/tracy.zig");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.audio);
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

	/// Set the sound track to the one given and wait between 5 and 20 seconds to play
	/// a music chosen at random in the track.
	pub fn playSoundTrack(self: *AudioSubsystem, soundTrack: SoundTrack) void {
		const random = self.musicManager.prng.random();
		self.playSoundTrackIn(soundTrack, random.intRangeAtMostBiased(i64, 5000, 20000));
	}

	pub fn playSoundTrackIn(self: *AudioSubsystem, soundTrack: SoundTrack, time: i64) void {
		self.musicManager.stopCurrentMusic();
		self.musicManager.soundTrack = soundTrack;

		const random = self.musicManager.prng.random();
		self.musicManager.soundTrack.position = random.uintLessThanBiased(usize, soundTrack.items.len);
		self.musicManager.nextMusicTime = std.time.milliTimestamp() + time;
	}

	pub fn update(self: *AudioSubsystem) void {
		const zone = tracy.ZoneN(@src(), "Update audio subsystem");
		defer zone.End();
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

	/// Change  to the next item in the sound track if the current music is done playing
	pub fn update(self: *MusicManager) void {
		const subsystem = @fieldParentPtr(AudioSubsystem, "musicManager", self);
		if (self.currentlyPlaying) |sound| {
			if (c.ma_sound_is_playing(sound) == 0) {
				const zone = tracy.ZoneN(@src(), "Destroy current music");
				defer zone.End();

				c.ma_sound_uninit(sound);
				self.allocator.destroy(sound);
				self.currentlyPlaying = null;

				// add a silence moment that can last from 15 to 30 seconds
				const random = self.prng.random();
				self.nextMusicTime = std.time.milliTimestamp() + random.intRangeAtMostBiased(i64, 15000, 30000);
				log.debug("Start next music in {d} seconds", .{ @divTrunc(self.nextMusicTime - std.time.milliTimestamp(), 1000) });
			}
		} else if (std.time.milliTimestamp() >= self.nextMusicTime) { // time for the next music to play
			if (self.soundTrack.getNextItem()) |nextItem| {
				const zone = tracy.ZoneN(@src(), "Load next music");
				defer zone.End();
				zone.Text(nextItem);

				const sound = self.allocator.create(c.ma_sound) catch return;
				if (c.ma_sound_init_from_file(subsystem.engine, nextItem, c.MA_SOUND_FLAG_ASYNC |
					c.MA_SOUND_FLAG_NO_PITCH | c.MA_SOUND_FLAG_NO_SPATIALIZATION | c.MA_SOUND_FLAG_STREAM, null, null, sound) != c.MA_SUCCESS) {
					std.log.scoped(.audio).warn("Could not load music '{s}'", .{ nextItem });
					return;
				}
				c.ma_sound_set_volume(sound, 0.4);
				c.ma_sound_set_fade_in_milliseconds(sound, 0, 1, 5000);
				if (c.ma_sound_start(sound) != c.MA_SUCCESS) {
					std.log.scoped(.audio).warn("Could not start music '{s}'", .{ nextItem });
				}
				self.currentlyPlaying = sound;
				self.soundTrack.increment();
			}
		}

	}

	/// Fade out the music for 5 seconds and then stop it.
	pub fn stopCurrentMusic(self: *MusicManager) void {
		const subsystem = @fieldParentPtr(AudioSubsystem, "musicManager", self);
		const engine = subsystem.engine;
		if (self.currentlyPlaying) |sound| {
			c.ma_sound_set_fade_in_milliseconds(sound, -1, 0, 5000);
			c.ma_sound_set_stop_time_in_pcm_frames(sound, c.ma_engine_get_time(engine) + c.ma_engine_get_sample_rate(engine) * 5);
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
