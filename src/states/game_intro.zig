const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const nvg = @import("nanovg");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const PlayState = @import("play.zig").PlayState;
const ui = @import("../ui.zig");

const Job = @import("../loop.zig").Job;

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

pub const GameIntroState = struct {
    textAlpha: u8 = 0,
    fontSize: f32 = 48.0,
    startTime: f64,
    fadeOutStartTime: ?f64 = null,

    pub fn init(game: *Game) GameIntroState {
        const soundTrack = @import("../audio.zig").SoundTrack{
            .items = &.{
                "assets/music/music-main-menu.mp3",
                // TODO: some kind of wait ethereal new-age music
            },
        };
        game.audio.playSoundTrackIn(soundTrack, 100);

        return GameIntroState{
            .startTime = Game.getTime(),
        };
    }

    pub fn render(self: *GameIntroState, game: *Game, renderer: *Renderer) void {
        _ = self;
        _ = game;
        _ = renderer;
    }

    pub fn renderUI(self: *GameIntroState, game: *Game, renderer: *Renderer) void {
        const size = renderer.framebufferSize;
        const vg = renderer.vg;

        // The time in seconds since the game intro started
        const time = (Game.getTime() - self.startTime) / 1000;

        const centerX = size.x() / 2;
        const centerY = size.y() / 2;

        const pressed = game.window.getMouseButton(.left) == .press;

        if (time <= 3) {
            self.textAlpha = @as(u8, @intFromFloat(255 * (time / 3)));
        } else if (self.fadeOutStartTime) |fadeOut| {
            self.textAlpha = 255 - @as(
                u8,
                @intFromFloat(@min(
                    @as(f64, 255),
                    @max(
                        @as(f64, 0),
                        (time - fadeOut) * 255.0 / 2.0,
                    ),
                )),
            );
        }

        const text = "A long time ago in a galaxy far far away lived a planet...";
        vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
        vg.fontSize(self.fontSize);
        if (ui.coloredLabel(vg, game, "intro-label", text, .{}, centerX, centerY, nvg.rgba(self.textAlpha, self.textAlpha, self.textAlpha, self.textAlpha)) and self.textAlpha > 220) {
            self.fontSize = self.fontSize * 0.9 + 56.0 * 0.1;
        } else {
            self.fontSize = self.fontSize * 0.9 + 48.0 * 0.1;
        }

        if (pressed and self.fadeOutStartTime == null and self.textAlpha > 220) {
            self.fadeOutStartTime = time;
        }

        if (self.fadeOutStartTime != null and self.textAlpha == 0) {
            game.setState(PlayState);
        }
    }

    pub fn deinit(self: *GameIntroState, game: *Game) void {
        _ = self;
        _ = game;
    }
};
