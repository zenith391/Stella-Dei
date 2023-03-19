const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const nvg = @import("nanovg");
const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const Texture = @import("../renderer.zig").Texture;
const PlayState = @import("play.zig").PlayState;
const GameIntroState = @import("game_intro.zig").GameIntroState;
const ui = @import("../ui.zig");

const Planet = @import("../simulation/planet.zig").Planet;

const Job = @import("../loop.zig").Job;

const CubeMesh = @import("../utils.zig").CubeMesh;
const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

pub const MainMenuState = struct {
    planet: Planet,
    skybox: Texture,
    displacementX: f32 = 0,
    displacementY: f32 = 0,
    targetDisplacementX: f32 = 0,
    targetDisplacementY: f32 = 0,
    do_render: bool = true,
    newAlpha: u8 = 128,
    loadAlpha: u8 = 128,
    settingsAlpha: u8 = 128,
    exitAlpha: u8 = 128,

    pub fn init(game: *Game) MainMenuState {
        const soundTrack = @import("../audio.zig").SoundTrack{ .items = &.{
            "assets/music/music-main-menu.mp3",
        } };
        game.audio.playSoundTrackIn(soundTrack, 3000);

        var randomPrng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.milliTimestamp()));
        const seed = randomPrng.random().int(u64);

        var earthFile: ?std.fs.File = null;
        if (std.fs.cwd().openFile("assets/big-earth.png", .{})) |file| {
            earthFile = file;
        } else |err| err catch {}; // ignore error

        var planet = Planet.generate(game.allocator, if (@import("builtin").mode == .Debug) 7 else 8, 5000, seed, .{ .generate_terrain = earthFile == null }) catch unreachable;
        if (earthFile) |*file| {
            defer file.close();
            planet.loadFromImage(game.allocator, file) catch {};
        }

        // Create the skybox
        const skybox = Texture.initCubemap();
        const faces = [_]Texture.CubemapFace{ .PositiveX, .NegativeX, .PositiveY, .NegativeY, .PositiveZ, .NegativeZ };
        for (faces) |face| {
            skybox.loadCubemapFace(game.allocator, face, "assets/starsky-1024.png") catch {};
        }

        return MainMenuState{ .planet = planet, .skybox = skybox };
    }

    pub fn render(self: *MainMenuState, game: *Game, renderer: *Renderer) void {
        if (!self.do_render) return;
        const size = renderer.framebufferSize;
        const planet = &self.planet;
        const sunAngle = za.toRadians(@as(f32, 195.0));

        const sunPhi = @floatCast(f32, @mod(sunAngle, 2 * std.math.pi));
        const sunTheta = za.toRadians(@as(f32, 90.0));
        const solarVector = Vec3.new(@cos(sunPhi) * @sin(sunTheta), @sin(sunPhi) * @sin(sunTheta), @cos(sunTheta));

        const zFar = planet.radius * 5;
        const zNear = zFar / 10000;

        self.displacementX = self.displacementX * 0.9 + self.targetDisplacementX * 0.1;
        self.displacementY = self.displacementY * 0.9 + self.targetDisplacementY * 0.1;

        var cameraPos = Vec3.new(-802 + self.displacementX, -913, 292 + self.displacementY)
            .norm().scale(10000 * 1.5);

        const planetTarget = Vec3.new(0, 0, 0).sub(cameraPos).norm();
        const target = planetTarget;

        // Start by rendering the skybox
        {
            const program = renderer.skyboxProgram;
            program.use();
            program.setUniformMat4("projMatrix", Mat4.perspective(70, size.x() / size.y(), 0.01, 100));
            var newViewMatrix = Mat4.lookAt(cameraPos, target, Vec3.new(0, 0, 1));
            // remove all the translation part
            newViewMatrix.data[0][3] = 0;
            newViewMatrix.data[1][3] = 0;
            newViewMatrix.data[2][3] = 0;
            newViewMatrix.data[3][3] = 1;
            newViewMatrix.data[3][0] = 0;
            newViewMatrix.data[3][1] = 0;
            newViewMatrix.data[3][2] = 0;
            program.setUniformMat4("viewMatrix", newViewMatrix);
            gl.depthMask(gl.FALSE);

            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.skybox.texture);
            program.setUniformInt("skyboxCubemap", 0);

            gl.bindVertexArray(CubeMesh.getVAO());
            gl.drawArrays(gl.TRIANGLES, 0, 36);

            gl.depthMask(gl.TRUE);
        }

        // Then render the planet
        {
            const program = renderer.terrainProgram;
            program.use();
            program.setUniformMat4("projMatrix", Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
            program.setUniformMat4("viewMatrix", Mat4.lookAt(cameraPos, target, Vec3.new(0, 0, 1)));

            const rot = @floatCast(f32, @mod(@intToFloat(f64, std.time.milliTimestamp()) / 1000.0 / 0.5, 360));
            const modelMatrix = Mat4.recompose(Vec3.new(0, 0, 0), Vec3.new(0, 0, rot), Vec3.new(1, 1, 1));
            program.setUniformMat4("modelMatrix", modelMatrix);

            program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
            program.setUniformVec3("lightDir", solarVector);
            program.setUniformFloat("lightIntensity", 1);
            program.setUniformVec3("viewPos", cameraPos);
            program.setUniformFloat("planetRadius", planet.radius);
            program.setUniformInt("displayMode", 0);
            program.setUniformInt("selectedVertex", 0);
            program.setUniformFloat("kmPerWaterMass", planet.getKmPerWaterMass());
            program.setUniformVec3("vegetationColor", Vec3.new(0.0, 0.7, 0.0));

            gl.activeTexture(gl.TEXTURE0);
            //gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.noiseCubemap.texture);
            program.setUniformInt("noiseCubemap", 0);

            const terrainNormalMap = renderer.textureCache.getExt("normal-map", .{ .mipmaps = true });
            gl.activeTexture(gl.TEXTURE1);
            gl.bindTexture(gl.TEXTURE_2D, terrainNormalMap.texture);
            program.setUniformInt("terrainNormalMap", 1);

            const waterNormalMap = renderer.textureCache.getExt("water-normal-map", .{ .mipmaps = true });
            gl.activeTexture(gl.TEXTURE2);
            gl.bindTexture(gl.TEXTURE_2D, waterNormalMap.texture);
            program.setUniformInt("waterNormalMap", 2);

            gl.enable(gl.CULL_FACE);
            defer gl.disable(gl.CULL_FACE);
            gl.frontFace(gl.CW);
            defer gl.frontFace(gl.CCW);

            planet.render(game.loop, .Normal, 0);
        }
    }

    pub fn renderUI(self: *MainMenuState, game: *Game, renderer: *Renderer) void {
        const size = renderer.framebufferSize;
        const vg = renderer.vg;

        const centerY = size.y() / 2.0;
        const columnHeight = 160.0;
        const columnX = 100.0;
        const columnY = centerY - columnHeight / 2.0;
        const pressed = game.window.getMouseButton(.left) == .press;

        const logoWidth: f32 = 1668.0 / 6.0;
        const logoHeight = logoWidth / (1668.0 / 353.0);
        ui.img(vg, size.x() / 2.0 - logoWidth / 2, 50, logoWidth, logoHeight, renderer.textureCache.get("logo"));

        vg.textAlign(.{ .horizontal = .left, .vertical = .top });
        vg.fontSize(26.0);
        if (ui.coloredLabel(vg, game, "new-label", "New Planet", .{}, columnX, columnY, nvg.rgba(255, 255, 255, self.newAlpha))) {
            self.newAlpha = 255;
            if (pressed) {
                game.setState(GameIntroState);
            }
        } else {
            self.newAlpha = 128;
        }

        if (ui.coloredLabel(vg, game, "load-label", "Load Planet", .{}, columnX, columnY + 40, nvg.rgba(255, 255, 255, self.loadAlpha))) {
            //self.loadAlpha = 255;
        } else {
            self.loadAlpha = 80;
        }

        if (ui.coloredLabel(vg, game, "settings-label", "Settings", .{}, columnX, columnY + 80, nvg.rgba(255, 255, 255, self.settingsAlpha))) {
            //self.settingsAlpha = 255;
        } else {
            self.settingsAlpha = 80;
        }

        if (ui.coloredLabel(vg, game, "exit-label", "Exit", .{}, columnX, columnY + 120, nvg.rgba(255, 255, 255, self.exitAlpha))) {
            self.exitAlpha = 255;
            if (pressed) {
                game.window.setShouldClose(true);
            }
        } else {
            self.exitAlpha = 128;
        }
    }

    pub fn mouseMoved(self: *MainMenuState, game: *Game, x: f32, y: f32, dx: f32, dy: f32) void {
        _ = dx;
        _ = dy;
        const size = game.renderer.framebufferSize;
        const nx = x / size.x() * 2 - 1;
        const ny = y / size.y() * 2 - 1;

        self.targetDisplacementX = nx * 300;
        self.targetDisplacementY = -ny * 100;
    }

    pub fn deinit(self: *MainMenuState, game: *Game) void {
        _ = game;
        self.planet.deinit();
        self.skybox.deinit();
    }
};
