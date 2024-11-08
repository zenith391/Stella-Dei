const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");
const glfw = @import("glfw");
const nvg = @import("nanovg");
const ui = @import("../ui.zig");
const utils = @import("../utils.zig");

const Game = @import("../main.zig").Game;
const Renderer = @import("../renderer.zig").Renderer;
const Texture = @import("../renderer.zig").Texture;
const Framebuffer = @import("../renderer.zig").Framebuffer;
const MouseButton = glfw.mouse_button.MouseButton;
const SoundTrack = @import("../audio.zig").SoundTrack;
const MainMenuState = @import("main_menu.zig").MainMenuState;

const Lifeform = @import("../simulation/life.zig").Lifeform;
const Planet = @import("../simulation/planet.zig").Planet;

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Vec4 = za.Vec4;
const Mat4 = za.Mat4;
const CubeMesh = @import("../utils.zig").CubeMesh;

pub const QuadMesh = struct {
    // zig fmt: off
    const vertices = [6 * 4]f32{
        // position + texture coords
        -1.0,  1.0, 0.0, 1.0,
        -1.0, -1.0, 0.0, 0.0,
         1.0, -1.0, 1.0, 0.0,
        -1.0,  1.0, 0.0, 1.0,
         1.0, -1.0, 1.0, 0.0,
         1.0,  1.0, 1.0, 1.0,
    };
    // zig fmt: on

    var quad_vao: ?gl.GLuint = null;

    pub fn getVAO() gl.GLuint {
        if (quad_vao == null) {
            var vao: gl.GLuint = undefined;
            gl.genVertexArrays(1, &vao);
            var vbo: gl.GLuint = undefined;
            gl.genBuffers(1, &vbo);

            gl.bindVertexArray(vao);
            gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
            gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @intCast(vertices.len * @sizeOf(f32))), &vertices, gl.STATIC_DRAW);
            gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @as(?*anyopaque, @ptrFromInt(0 * @sizeOf(f32)))); // position
            gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @as(?*anyopaque, @ptrFromInt(2 * @sizeOf(f32)))); // position
            gl.enableVertexAttribArray(0);
            gl.enableVertexAttribArray(1);
            quad_vao = vao;
        }
        return quad_vao.?;
    }
};

pub const SunMesh = struct {
    const IcosphereMesh = @import("../utils.zig").IcosphereMesh;

    var sun_mesh: ?IcosphereMesh = null;

    pub fn getMesh(allocator: std.mem.Allocator) IcosphereMesh {
        if (sun_mesh == null) {
            const mesh = IcosphereMesh.generate(allocator, 3, false) catch unreachable;
            gl.bindVertexArray(mesh.vao[0]);
            gl.bindBuffer(gl.ARRAY_BUFFER, mesh.vbo);
            gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), @as(?*anyopaque, @ptrFromInt(0 * @sizeOf(f32)))); // position
            gl.enableVertexAttribArray(0);
            gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @intCast(mesh.vertices.len * @sizeOf(f32))), mesh.vertices.ptr, gl.STREAM_DRAW);
            sun_mesh = mesh;
        }
        return sun_mesh.?;
    }

    pub fn deinit(allocator: std.mem.Allocator) void {
        if (sun_mesh) |mesh| {
            mesh.deinit(allocator);
            sun_mesh = null;
        }
    }
};

const GameTool = enum {
    None,
    /// When enabled, emits water at selected point on click
    EmitWater,
    /// When enabled, set vegetation level to 1 at selected point on click
    DrainWater,
    /// When enabled, drains all water near selected point on click
    PlaceVegetation,
    /// When enabled, place lifeform on click
    PlaceLife,
    RaiseTerrain,
    LowerTerrain,
};

pub const PlayState = struct {
    /// The previous mouse position that was recorded during dragging (to move the camera).
    dragStart: Vec2,
    planet: Planet,
    /// Noise cubemap used for rendering terrains with a terrain quality that
    /// seems higher than it is really.
    noiseCubemap: Texture,
    skyboxCubemap: Texture,
    framebuffer: Framebuffer,
    blurFramebuffer: Framebuffer,

    /// The position of the camera
    /// This is already scaled by cameraDistance
    cameraPos: Vec3 = Vec3.new(0, -8000, 2000),
    /// The target camera position, every frame, a linear interpolation is done
    /// between the current camera position and the target position, to create a
    /// smooth moving effect.
    targetCameraPos: Vec3 = Vec3.new(0, -8, 2),
    /// The distance the camera is from the planet's center
    cameraDistance: f32,
    targetCameraDistance: f32,
    freeCam: bool = false,
    /// Euler angles of the camera's rotation in degrees.
    /// This only applies when freeCam = true
    cameraRotation: Vec3 = Vec3.new(0, 0, 0),
    /// The index of the currently selected point
    selectedPoint: usize = 0,
    clickedPoint: usize = 0,
    displayMode: Planet.DisplayMode = .Normal,
    /// Inclination of rotation, in degrees
    axialTilt: f32 = 0, //23.4, // TODO: fix axial tilt with wind and solar vector
    /// The solar constant in W.m-2
    solarConstant: f32 = 1361,
    /// The time it takes for the planet to do a full rotation on itself, in seconds
    planetRotationTime: f32 = 86400,
    /// The time elapsed in seconds since the start of the game.
    /// Updated at every tick.
    gameTime: f64 = 0,
    /// The time elapsed in seconds since the start of the game.
    /// Updated at every frame. This will periodically resynchronise with gameTime
    /// The reason this exists is to have smooth rendering even when the simulation is slow
    renderGameTime: f64 = 0,
    /// The average time a tick takes to execute.
    averageUpdateTime: f32 = 0,
    /// Time scale for the simulation.
    /// This is the number of in-game seconds that passes for each real second
    /// TODO: only expose 3 selectable time scales like in most game (normal, fast, super fast)
    /// and they would have different values depending on the geological/biological/technological time scale
    timeScale: f32 = 6 * @as(f32, @floatFromInt(std.time.s_per_hour)),
    /// Whether the game is paused, this has the same effect as setting timeScale to
    /// 0 except it preserves the time scale value.
    paused: bool = false,
    showPlanetControl: bool = false,
    showPointDetails: bool = false,

    debug_showMoreInfo: bool = false,
    debug_clearWater: bool = false,
    debug_deluge: bool = false,
    debug_spawnRabbits: bool = false,
    /// Save the game on the next call to update()
    defer_saveGame: bool = false,
    showEscapeMenu: bool = false,

    selectedTool: GameTool = .None,
    meanTemperature: f32 = 0.0,

    pub fn init(game: *Game) PlayState {
        const soundTrack = SoundTrack{ .items = &.{
            "assets/music/music1.mp3",
            "assets/music/music2.mp3",
            "assets/music/music3.mp3",
        } };
        game.audio.playSoundTrack(soundTrack);

        // Create the noise cubemap for terrain detail
        const cubemap = Texture.initCubemap();
        var data: []u8 = game.allocator.alloc(u8, 512 * 512 * 3) catch unreachable;
        defer game.allocator.free(data);

        // The seed is constant as it should not be changed between plays for consistency
        var prng = std.rand.DefaultPrng.init(1234);
        var randomPrng = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));

        // Generate white noise (using the PRNG) to fill all of the cubemap's faces
        const faces = [_]Texture.CubemapFace{ .PositiveX, .NegativeX, .PositiveY, .NegativeY, .PositiveZ, .NegativeZ };
        for (faces) |face| {
            var y: usize = 0;
            while (y < 512) : (y += 1) {
                var x: usize = 0;
                while (x < 512) : (x += 1) {
                    // Currently, cubemap faces are in RGB format so only the red channel
                    // is filled. (TODO: switch to GRAY8 format)
                    data[(y * 512 + x) * 3 + 0] = prng.random().int(u8);
                }
            }
            cubemap.setCubemapFace(face, 512, 512, data);
        }

        // Create the skybox
        const skybox = Texture.initCubemap();
        for (faces) |face| {
            skybox.loadCubemapFace(game.allocator, face, "assets/starsky-1024.png") catch {};
        }

        // TODO: make a loading scene
        const planetRadius = 5000; // a radius a bit smaller than Earth's (~6371km)
        const seed = randomPrng.random().int(u64);
        const subdivisions = if (@import("builtin").mode == .Debug) 6 else 7;
        //const subdivisions = 6;
        const planet = Planet.generate(game.allocator, subdivisions, planetRadius, seed, .{}) catch unreachable;

        if (false) {
            // Load Earth
            var file = std.fs.cwd().openFile("assets/big-earth.png", .{}) catch unreachable;
            defer file.close();
            planet.loadFromImage(game.allocator, &file) catch {};
        }

        // Temperature difference breaks the start of the game for some reason
        // TODO: fix the bug
        @memset(planet.temperature, 293.15);

        Lifeform.initMeshes(game.allocator) catch unreachable;

        const framebuffer = Framebuffer.create(800, 600) catch unreachable;
        const blurFramebuffer = Framebuffer.create(800, 600) catch unreachable;

        const cursorPos = game.window.getCursorPos();
        std.valgrind.callgrind.startInstrumentation();
        return PlayState{
            .dragStart = Vec2.new(@as(f32, @floatCast(cursorPos.xpos)), @as(f32, @floatCast(cursorPos.ypos))),
            .noiseCubemap = cubemap,
            .skyboxCubemap = skybox,
            .planet = planet,
            .framebuffer = framebuffer,
            .blurFramebuffer = blurFramebuffer,
            .cameraDistance = planetRadius * 10,
            .targetCameraDistance = planetRadius * 2.5,
        };
    }

    pub fn render(self: *PlayState, game: *Game, renderer: *Renderer) void {
        const window = renderer.window;
        const size = renderer.framebufferSize;

        // Move the camera when dragging the mouse
        if (self.freeCam) {
            const right = self.cameraPos.cross(Vec3.forward()).norm();
            const down = self.cameraPos.cross(right).norm();
            _ = down;

            const yaw = za.toRadians(self.cameraRotation.x());
            const pitch = za.toRadians(self.cameraRotation.y());
            const forward = Vec3.new(
                std.math.cos(yaw) * std.math.cos(pitch),
                std.math.sin(yaw) * std.math.cos(pitch),
                std.math.sin(pitch),
            );
            const speed = (self.cameraPos.length() - self.planet.radius) / 100.0;
            if (window.getKey(.w) == .press) {
                self.cameraPos = self.cameraPos.add(forward.scale(speed));
            }
            if (window.getKey(.s) == .press) {
                self.cameraPos = self.cameraPos.sub(forward.scale(speed));
            }

            {
                const cameraPoint = self.planet.transformedPoints[self.planet.getNearestPointTo(self.cameraPos)];
                if (self.cameraPos.length() < cameraPoint.length() + 100) {
                    self.cameraPos = self.cameraPos.norm().scale(cameraPoint.length() + 100);
                }
            }
        } else {
            if (window.getMouseButton(.right) == .press and !self.showEscapeMenu) {
                const glfwCursorPos = game.window.getCursorPos();
                const cursorPos = Vec2.new(@as(f32, @floatCast(glfwCursorPos.xpos)), @as(f32, @floatCast(glfwCursorPos.ypos)));
                const delta = cursorPos.sub(self.dragStart).scale(1.0 / 100.0);
                const right = self.targetCameraPos.cross(Vec3.forward()).norm();
                const backward = self.targetCameraPos.cross(right).norm();
                self.targetCameraPos = self.targetCameraPos
                    .add(right.scale(delta.x())
                    .add(backward.scale(-delta.y()))
                    .scale(self.targetCameraDistance / 5));
                self.dragStart = cursorPos;

                self.targetCameraPos = self.targetCameraPos.norm()
                    .scale(self.targetCameraDistance);
            }

            {
                const cameraPoint = self.planet.transformedPoints[self.planet.getNearestPointTo(self.targetCameraPos)];
                if (self.targetCameraDistance < cameraPoint.length() + 100) {
                    self.targetCameraDistance = cameraPoint.length() + 100;
                }
            }

            // Smooth camera move using linear interpolation
            self.targetCameraPos = self.targetCameraPos.norm()
                .scale(self.targetCameraDistance);
            if (!(std.math.approxEqAbs(f32, self.cameraPos.x(), self.targetCameraPos.x(), 0.01) and
                std.math.approxEqAbs(f32, self.cameraPos.y(), self.targetCameraPos.y(), 0.01) and
                std.math.approxEqAbs(f32, self.cameraPos.z(), self.targetCameraPos.z(), 0.01) and
                std.math.approxEqAbs(f32, self.cameraDistance, self.targetCameraDistance, 0.01)))
            {
                // TODO: maybe use Quaternion lerp ? It could help on rotation near the poles.
                self.cameraPos = self.cameraPos.scale(0.9).add(self.targetCameraPos.scale(0.1));
                self.cameraDistance = self.cameraDistance * 0.9 + self.targetCameraDistance * 0.1;
                self.cameraPos = self.cameraPos.norm()
                    .scale(self.cameraDistance);
            }
        }

        const scale = 1;
        const fbWidth = @as(c_int, @intFromFloat(size.x() * scale));
        const fbHeight = @as(c_int, @intFromFloat(size.y() * scale));
        if (fbWidth != self.framebuffer.width or fbHeight != self.framebuffer.height) {
            self.framebuffer.deinit();
            self.framebuffer = Framebuffer.create(fbWidth, fbHeight) catch unreachable;

            self.blurFramebuffer.deinit();
            self.blurFramebuffer = Framebuffer.create(fbWidth, fbHeight) catch unreachable;
        }

        {
            self.framebuffer.bind();
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            gl.enable(gl.DEPTH_TEST);
            gl.viewport(0, 0, fbWidth, fbHeight);
            defer gl.viewport(0, 0, @as(c_int, @intFromFloat(size.x())), @as(c_int, @intFromFloat(size.y())));

            self.renderScene(game, renderer);
            self.framebuffer.unbind();
        }

        // Compute a texture from the HDR framebuffer with only bright parts
        {
            const program = renderer.postprocessProgram;
            self.framebuffer.bind();
            defer self.framebuffer.unbind();

            const attachments: [1]gl.GLenum = .{gl.COLOR_ATTACHMENT1};
            const ogAttachments: [1]gl.GLenum = .{gl.COLOR_ATTACHMENT0};
            gl.drawBuffers(1, &attachments);
            defer gl.drawBuffers(1, &ogAttachments);

            program.use();
            program.setUniformBool("doBrightTexture", true);
            gl.viewport(0, 0, fbWidth, fbHeight);
            defer gl.viewport(0, 0, @as(c_int, @intFromFloat(size.x())), @as(c_int, @intFromFloat(size.y())));

            gl.bindVertexArray(QuadMesh.getVAO());
            gl.disable(gl.DEPTH_TEST);
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, self.framebuffer.colorTextures[0]);
            gl.drawArrays(gl.TRIANGLES, 0, 6);
        }

        // Blur the bright part to create bloom
        {
            const program = renderer.postprocessProgram;

            // Horizontal blurring (framebuffer -> blurFramebuffer)
            program.use();
            program.setUniformBool("doBrightTexture", false);
            program.setUniformBool("doBlurring", true);

            for (0..4) |i| {
                program.setUniformBool("horizontalBlurring", i % 2 == 0);

                const source = if (i % 2 == 0) self.framebuffer.colorTextures[1] else self.blurFramebuffer.colorTextures[0];
                const target = if (i % 2 == 0) self.blurFramebuffer else self.framebuffer;
                {
                    target.bind();
                    defer target.unbind();
                    gl.viewport(0, 0, fbWidth, fbHeight);
                    defer gl.viewport(0, 0, @as(c_int, @intFromFloat(size.x())), @as(c_int, @intFromFloat(size.y())));
                    var attachments: [1]gl.GLenum = .{gl.COLOR_ATTACHMENT1};
                    if (i % 2 == 0) {
                        attachments[0] = gl.COLOR_ATTACHMENT0;
                    }
                    const ogAttachments: [1]gl.GLenum = .{gl.COLOR_ATTACHMENT0};
                    gl.drawBuffers(1, &attachments);
                    defer gl.drawBuffers(1, &ogAttachments);

                    gl.bindVertexArray(QuadMesh.getVAO());
                    gl.disable(gl.DEPTH_TEST);
                    gl.activeTexture(gl.TEXTURE0);
                    gl.bindTexture(gl.TEXTURE_2D, source);
                    gl.drawArrays(gl.TRIANGLES, 0, 6);
                }
            }
        }

        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        {
            const program = renderer.postprocessProgram;
            const sunPhi: f32 = @as(f32, @floatCast(@mod(self.renderGameTime / self.planetRotationTime * 2 * std.math.pi, 2 * std.math.pi)));
            const sunTheta: f32 = std.math.pi / 2.0;
            const solarVector = Vec3.new(@cos(sunPhi) * @sin(sunTheta), @sin(sunPhi) * @sin(sunTheta), @cos(sunTheta));
            const zFar = self.planet.radius * 5;
            const zNear = zFar / 10000;
            const target = self.getViewTarget();

            program.use();
            program.setUniformInt("screenTexture", 0);
            program.setUniformInt("bloomTexture", 1);
            program.setUniformInt("screenDepth", 2);
            program.setUniformMat4("projMatrix", Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
            program.setUniformMat4("viewMatrix", Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));
            program.setUniformVec3("viewPos", self.cameraPos);
            program.setUniformVec3("lightDir", solarVector);
            program.setUniformFloat("planetRadius", self.planet.radius);
            program.setUniformFloat("atmosphereRadius", self.planet.radius + 50 * 10); // * HEIGHT_ELEVATION
            program.setUniformFloat("lightIntensity", self.solarConstant / 1500);
            program.setUniformBool("enableAtmosphere", self.displayMode == .Normal);
            program.setUniformBool("doBrightTexture", false);
            program.setUniformBool("doBlurring", false);

            gl.bindVertexArray(QuadMesh.getVAO());
            gl.disable(gl.DEPTH_TEST);
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, self.framebuffer.colorTextures[0]); // color
            gl.activeTexture(gl.TEXTURE1);
            gl.bindTexture(gl.TEXTURE_2D, self.framebuffer.colorTextures[1]); // blur
            gl.activeTexture(gl.TEXTURE2);
            gl.bindTexture(gl.TEXTURE_2D, self.framebuffer.depthTexture); // depth
            gl.drawArrays(gl.TRIANGLES, 0, 6);
        }

        if (!self.paused) {
            self.renderGameTime = self.renderGameTime + self.timeScale / game.fps;
        }
    }

    fn getViewTarget(self: *PlayState) Vec3 {
        const right = self.cameraPos.cross(Vec3.forward()).norm();
        const forward = self.cameraPos.cross(right).norm().negate();
        const planetTarget = Vec3.new(0, 0, 0).sub(self.cameraPos).norm();
        const distToPlanet = self.cameraDistance - self.planet.radius;
        var target = self.cameraPos.add(Vec3.lerp(planetTarget, forward, std.math.pow(f32, 2, -distToPlanet / self.planet.radius * 5) * 0.6));

        if (self.freeCam) {
            //const rotMatrix = Mat4.fromEulerAngles(self.cameraRotation);
            const yaw = za.toRadians(self.cameraRotation.x());
            const pitch = za.toRadians(self.cameraRotation.y());
            const direction = Vec3.new(
                std.math.cos(yaw) * std.math.cos(pitch),
                std.math.sin(yaw) * std.math.cos(pitch),
                std.math.sin(pitch),
            );
            target = self.cameraPos.add(direction);
        }

        return target;
    }

    pub fn renderScene(self: *PlayState, game: *Game, renderer: *Renderer) void {
        const size = renderer.framebufferSize;

        const planet = &self.planet;
        const sunPhi: f32 = @as(f32, @floatCast(@mod(self.renderGameTime / self.planetRotationTime * 2 * std.math.pi, 2 * std.math.pi)));
        const sunTheta: f32 = std.math.pi / 2.0;
        const solarVector = Vec3.new(@cos(sunPhi) * @sin(sunTheta), @sin(sunPhi) * @sin(sunTheta), @cos(sunTheta));

        const zFar = planet.radius * 5;
        const zNear = zFar / 10000;

        const target = self.getViewTarget();

        // Start by rendering the skybox
        {
            const program = renderer.skyboxProgram;
            program.use();
            program.setUniformMat4("projMatrix", Mat4.perspective(70, size.x() / size.y(), 0.01, 100));
            var newViewMatrix = Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1));
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
            gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.skyboxCubemap.texture);
            program.setUniformInt("skyboxCubemap", 0);

            gl.bindVertexArray(CubeMesh.getVAO());
            gl.drawArrays(gl.TRIANGLES, 0, 36);

            gl.depthMask(gl.TRUE);
        }

        // Then render the sun
        {
            // TODO: do like skybox so it looks infinitely far
            const program = renderer.sunProgram;
            program.use();
            program.setUniformMat4("projMatrix", Mat4.perspective(70, size.x() / size.y(), 1, 1000000));
            program.setUniformMat4("viewMatrix", Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));
            const modelMatrix = Mat4.recompose(solarVector.scale(300000), Vec3.new(0, 0, 0), Vec3.new(8000, 8000, 8000));
            program.setUniformMat4("modelMatrix", modelMatrix);

            const mesh = SunMesh.getMesh(game.allocator);
            gl.bindVertexArray(mesh.vao[0]);
            gl.drawElements(gl.TRIANGLES, @as(c_int, @intCast(mesh.indices.len)), gl.UNSIGNED_INT, null);
        }

        // Then render the planet
        {
            const program = renderer.terrainProgram;
            program.use();
            program.setUniformMat4("projMatrix", Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
            program.setUniformMat4("viewMatrix", Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

            const modelMatrix = Mat4.recompose(Vec3.new(0, 0, 0), Vec3.new(0, 0, 0), Vec3.new(1, 1, 1));
            program.setUniformMat4("modelMatrix", modelMatrix);

            program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
            program.setUniformVec3("lightDir", solarVector);
            program.setUniformFloat("lightIntensity", self.solarConstant / 1500);
            program.setUniformVec3("viewPos", self.cameraPos);
            program.setUniformFloat("planetRadius", planet.radius);
            program.setUniformInt("displayMode", @intFromEnum(self.displayMode)); // display mode
            program.setUniformVec3("selectedVertexPos", planet.transformedPoints[self.selectedPoint]);
            program.setUniformFloat("kmPerWaterMass", planet.getKmPerWaterMass());
            program.setUniformVec3("vegetationColor", utils.getWavelengthColor(planet.plantColorWavelength));

            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.noiseCubemap.texture);
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

            // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
            planet.render(game.loop, self.displayMode, self.axialTilt);
            // gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
        }

        // Then the clouds
        {
            const program = renderer.cloudsProgram;
            program.use();
            program.setUniformMat4("projMatrix", Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
            program.setUniformMat4("viewMatrix", Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

            const modelMatrix = Mat4.recompose(Vec3.new(0, 0, 0), Vec3.new(0, 0, 0), Vec3.new(1, 1, 1));
            program.setUniformMat4("modelMatrix", modelMatrix);

            program.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
            program.setUniformVec3("lightDir", solarVector);
            program.setUniformFloat("lightIntensity", self.solarConstant / 1500);
            program.setUniformVec3("viewPos", self.cameraPos);
            program.setUniformFloat("planetRadius", planet.radius);
            program.setUniformFloat("kmPerWaterMass", planet.getKmPerWaterMass());
            program.setUniformFloat("gameTime", @as(f32, @floatCast(self.gameTime)));

            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.noiseCubemap.texture);
            program.setUniformInt("noiseCubemap", 0);

            const waterNormalMap = renderer.textureCache.getExt("water-normal-map", .{ .mipmaps = true });
            gl.activeTexture(gl.TEXTURE1);
            gl.bindTexture(gl.TEXTURE_2D, waterNormalMap.texture);
            program.setUniformInt("waterNormalMap", 1);

            if (self.displayMode == .Normal)
                planet.renderWater();
        }

        const entity = renderer.entityProgram;
        entity.use();
        entity.setUniformMat4("projMatrix", Mat4.perspective(70, size.x() / size.y(), zNear, zFar));
        entity.setUniformMat4("viewMatrix", Mat4.lookAt(self.cameraPos, target, Vec3.new(0, 0, 1)));

        gl.frontFace(gl.CCW);
        for (planet.lifeforms.items) |lifeform| {
            const modelMat = Mat4.recompose(lifeform.position, Vec3.new(0, 0, 0), Vec3.new(1, 1, 1));
            entity.setUniformMat4("modelMatrix", modelMat);
            entity.setUniformVec3("lightColor", Vec3.new(1.0, 1.0, 1.0));
            entity.setUniformVec3("lightDir", solarVector);

            const mesh = lifeform.getMesh();
            gl.bindVertexArray(mesh.vao);
            gl.drawArrays(gl.TRIANGLES, 0, mesh.numTriangles);
        }
    }

    // As updated slices (temperature and water elevation) are updated by a
    // swap. This is atomic.
    pub fn update(self: *PlayState, game: *Game, dt: f32) void {
        if (self.showEscapeMenu) return;

        const planet = &self.planet;

        const sunPhi: f32 = @as(f32, @floatCast(@mod(self.gameTime / self.planetRotationTime * 2 * std.math.pi, 2 * std.math.pi)));
        const sunTheta: f32 = std.math.pi / 2.0;
        const solarVector = Vec3.new(@cos(sunPhi) * @sin(sunTheta), @sin(sunPhi) * @sin(sunTheta), @cos(sunTheta));

        if (self.selectedTool == .EmitWater and game.window.getMouseButton(.left) == .press) {
            const kmPerWaterMass = planet.getKmPerWaterMass();
            if (planet.waterMass[self.selectedPoint] < 25 / kmPerWaterMass) {
                planet.waterMass[self.selectedPoint] += 0.00005 * self.timeScale / kmPerWaterMass;
            }
        }
        if (self.selectedTool == .PlaceVegetation and game.window.getMouseButton(.left) == .press) {
            planet.vegetation[self.selectedPoint] = 1;
        }

        if (self.selectedTool == .DrainWater and game.window.getMouseButton(.left) == .press) {
            planet.waterMass[self.selectedPoint] = 0;
            for (planet.getNeighbours(self.selectedPoint)) |idx| {
                planet.waterMass[idx] = 0;
            }
        }

        if (self.selectedTool == .RaiseTerrain and game.window.getMouseButton(.left) == .press) {
            if (planet.elevation[self.selectedPoint] < planet.radius + 20) {
                planet.elevation[self.selectedPoint] += 0.4;
            }
            for (planet.getNeighbours(self.selectedPoint)) |idx| {
                if (planet.elevation[idx] < planet.radius + 20) {
                    planet.elevation[idx] += 0.2;
                }
            }
        }

        if (self.selectedTool == .LowerTerrain and game.window.getMouseButton(.left) == .press) {
            if (planet.elevation[self.selectedPoint] > planet.radius - 20) {
                planet.elevation[self.selectedPoint] -= 0.4;
            }
            for (planet.getNeighbours(self.selectedPoint)) |idx| {
                if (planet.elevation[idx] > planet.radius - 20) {
                    planet.elevation[idx] -= 0.2;
                }
            }
        }

        if (self.debug_clearWater) {
            @memset(self.planet.waterMass, 0);
            @memset(self.planet.waterVaporMass, 0);
            self.debug_clearWater = false;
        }

        if (self.debug_deluge) {
            @memset(self.planet.waterVaporMass, 5_000_000);
            self.debug_deluge = false;
        }

        if (self.debug_spawnRabbits) {
            var prng = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
            const random = prng.random();

            var i: usize = 0;
            while (i < 10) : (i += 1) {
                const point = planet.transformedPoints[random.intRangeLessThanBiased(usize, 0, planet.temperature.len)];
                const lifeform = Lifeform.init(point, .Rabbit, self.gameTime);
                planet.addLifeform(lifeform) catch unreachable;
            }
            self.debug_spawnRabbits = false;
        }

        if (!self.paused) {
            // The planet is simulated with a time scale divided by the number
            // of simulation steps. So that if there are more steps, the same
            // time speed is kept but the precision is increased.

            var timer = std.time.Timer.start() catch unreachable;
            planet.simulate(game.loop, .{
                .dt = dt,
                .solarConstant = self.solarConstant,
                .timeScale = self.timeScale,
                .gameTime = self.gameTime,
                .planetRotationTime = self.planetRotationTime,
                .solarVector = solarVector,
            });
            const updateTime = @as(f32, @floatFromInt(timer.lap() / 1_000)) / 1_000_000;

            // TODO: use std.time.milliTimestamp or std.time.Timer for accurate game time
            self.gameTime += updateTime * self.timeScale;
            self.averageUpdateTime = self.averageUpdateTime * 0.9 + updateTime * 0.1;
            // Re-synchronise render game time with real game time
            self.renderGameTime = self.gameTime;
        }

        const targetMusicVolume: f32 = blk: {
            if (self.paused) {
                break :blk 0.1;
            } else {
                break :blk 0.4;
            }
        };

        const t = 0.6 * dt;
        game.audio.setMusicVolume(game.audio.getMusicVolume() * (1 - t) + targetMusicVolume * t);

        if (self.defer_saveGame) {
            self.saveGame() catch |err| {
                // TODO: handle error
                err catch {};
            };
            self.defer_saveGame = false;
        }
    }

    pub fn keyCallback(self: *PlayState, game: *Game, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
        _ = scancode;
        _ = mods;
        if (action == .press) {
            if (key == .escape) {
                self.showEscapeMenu = !self.showEscapeMenu;
            }

            if (self.showEscapeMenu) return;
            if (key == .F3) {
                self.debug_showMoreInfo = !self.debug_showMoreInfo;
            }
            if (key == .F5) {
                const numEnumFields = @as(c_int, std.meta.fields(Planet.DisplayMode).len);
                self.displayMode = @as(Planet.DisplayMode, @enumFromInt(@mod(@intFromEnum(self.displayMode) + 1, numEnumFields)));
            }
            if (key == .F6) {
                if (self.freeCam) {
                    self.targetCameraDistance = self.cameraPos.length();
                }
                self.freeCam = !self.freeCam;

                game.renderer.window.setInputModeCursor(
                    if (self.freeCam) .disabled else .normal,
                );
            }
            if (key == .space) {
                self.paused = !self.paused;
            }

            if (key == .kp_add) {
                self.timeScale += 10;
            } else if (key == .kp_subtract) {
                self.timeScale -= 10;
            }
        }
    }

    pub fn mousePressed(self: *PlayState, game: *Game, button: MouseButton) void {
        if (self.showEscapeMenu) return;

        if (self.selectedTool == .PlaceLife and button == .left) {
            const planet = &self.planet;
            const point = self.selectedPoint;
            const pointPos = planet.transformedPoints[point];
            const lifeform = Lifeform.init(pointPos, .Rabbit, self.gameTime);
            // planet.lifeformsLock.lock();
            // defer planet.lifeformsLock.unlock();
            planet.addLifeform(lifeform) catch unreachable;
        }

        if (self.selectedTool == .None and button == .left) {
            self.showPointDetails = true;
            self.clickedPoint = self.selectedPoint;
        }

        if (button == .right) {
            const cursorPos = game.window.getCursorPos();
            self.dragStart = Vec2.new(@as(f32, @floatCast(cursorPos.xpos)), @as(f32, @floatCast(cursorPos.ypos)));
        }
    }

    pub fn mouseScroll(self: *PlayState, _: *Game, yOffset: f64) void {
        if (self.showEscapeMenu) return;

        const zFar = self.planet.radius * 5;
        const zNear = zFar / 10000;

        const minDistance = self.planet.radius + zNear;
        const maxDistance = self.planet.radius * 5;
        self.targetCameraDistance = std.math.clamp(self.targetCameraDistance - (@as(f32, @floatCast(yOffset)) * self.cameraDistance / 50), minDistance, maxDistance);
    }

    pub fn mouseMoved(self: *PlayState, game: *Game, x: f32, y: f32, dx: f32, dy: f32) void {
        if (self.showEscapeMenu) return;
        if (self.freeCam) {
            const mouseSensitivity = 0.1;
            self.cameraRotation.data[0] -= dx * mouseSensitivity;
            self.cameraRotation.data[1] -= dy * mouseSensitivity;
        }

        const windowSize = game.window.getFramebufferSize();
        // Transform screen coordinates to Normalized Device Space coordinates
        const ndsX = 2 * x / @as(f32, @floatFromInt(windowSize.width)) - 1;
        const ndsY = 1 - 2 * y / @as(f32, @floatFromInt(windowSize.height));
        var cursorVector = za.Vec4.new(ndsX, ndsY, -1, 1);

        // 'unproject' the coordinates by using the inversed projection matrix
        const zFar = self.planet.radius * 5;
        const zNear = zFar / 10000;
        const projMatrix = Mat4.perspective(70, @as(f32, @floatFromInt(windowSize.width)) / @as(f32, @floatFromInt(windowSize.height)), zNear, zFar);
        cursorVector = projMatrix.inv().mulByVec4(cursorVector);

        // put to world space by multiplying by inverse of view matrix
        cursorVector.data[2] = -1;
        cursorVector.data[3] = 0; // we only want directions so set z and w
        const viewMatrix = Mat4.lookAt(self.cameraPos, Vec3.new(0, 0, 0), Vec3.new(0, 0, 1));
        cursorVector = viewMatrix.inv().mulByVec4(cursorVector);
        const worldSpaceCursor = Vec3.new(cursorVector.x(), cursorVector.y(), cursorVector.z());
        //std.log.info("{d}", .{ worldSpaceCursor });

        // Select the closest point that the camera is facing.
        // To do this, it gets the point that has the lowest distance to the
        // position of the camera.
        const pos = self.cameraPos.add(worldSpaceCursor.scale(self.cameraPos.length() / 2)).norm().scale(self.planet.radius + 20);
        var closestPointDist: f32 = std.math.inf(f32);
        var closestPoint: usize = undefined;
        for (self.planet.transformedPoints, 0..) |point, i| {
            if (point.distance(pos) < closestPointDist) {
                closestPoint = i;
                closestPointDist = point.distance(pos);
            }
        }
        self.selectedPoint = closestPoint;
    }

    pub fn renderUI(self: *PlayState, game: *Game, renderer: *Renderer) void {
        const size = renderer.framebufferSize;
        const vg = renderer.vg;
        const pressed = game.window.getMouseButton(.left) == .press;
        const glfwCursorPos = game.window.getCursorPos();
        const cursorPos = Vec2.new(@as(f32, @floatCast(glfwCursorPos.xpos)), @as(f32, @floatCast(glfwCursorPos.ypos)));
        _ = cursorPos;

        {
            const barHeight = 50;
            vg.beginPath();
            vg.fillColor(nvg.rgbaf(1, 1, 1, 0.7));
            vg.rect(0, size.y() - barHeight, size.x(), barHeight);
            vg.fill();
        }

        {
            //var prng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.milliTimestamp()));
            var prng = std.rand.DefaultPrng.init(0);
            const random = prng.random();
            if (!self.paused) {
                var meanTemperature: f32 = 0;
                var i: usize = 0;
                while (i < 1000) : (i += 1) {
                    const pointIdx = random.intRangeLessThanBiased(usize, 0, self.planet.temperature.len);
                    meanTemperature += self.planet.temperature[pointIdx];
                }
                meanTemperature /= 1000;
                self.meanTemperature = self.meanTemperature * 0.9 + meanTemperature * 0.1;
            }
            vg.textAlign(.{ .horizontal = .left, .vertical = .middle });
            vg.fontSize(20.0);
            if (ui.coloredLabel(vg, game, "mean-temperature", "{d:.1}°C", .{self.meanTemperature - 273.15}, 150, size.y() - 25, nvg.rgba(255, 255, 255, 255))) {
                if (pressed) {
                    self.showPlanetControl = true;
                }
            }

            ui.label(vg, game, "{d:.1} ups", .{1.0 / self.averageUpdateTime}, 250, size.y() - 25);

            vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
            ui.label(vg, game, "Year {d:.1}", .{self.gameTime / 86400 / 365}, size.x() / 2, size.y() - 25);
        }

        if (self.showPlanetControl) {
            const panelWidth = 300;
            const panelHeight = 280;

            self.showPlanetControl = ui.window(vg, game, "planet-control-window", panelWidth, panelHeight);
            defer ui.endWindow(vg);

            vg.textAlign(.{ .horizontal = .center, .vertical = .top });
            ui.label(vg, game, "Solar Constant", .{}, 90, 0);
            ui.label(vg, game, "{d} W/m²", .{self.solarConstant}, 90, 30);
            if (ui.button(vg, game, "solar-constant-minus", 0, 30, 20, 20, "-")) {
                self.solarConstant = @max(0, self.solarConstant - 100);
            }
            if (ui.button(vg, game, "solar-constant-plus", 160, 30, 20, 20, "+")) {
                self.solarConstant = @min(self.solarConstant + 100, 5000);
            }

            if (ui.button(vg, game, "clear-water", panelWidth / 2 - (170 / 2), 130, 170, 40, "Clear all water")) {
                self.debug_clearWater = true;
            }
            if (ui.button(vg, game, "deluge", panelWidth / 2 - (170 / 2), 180, 170, 40, "Deluge")) {
                self.debug_deluge = true;
            }

            // if (pressed and !(cursorPos.x() >= panelX and cursorPos.x() < panelX + panelWidth and cursorPos.y() >= panelY and cursorPos.y() < panelY + panelHeight)) {
            //     self.showPlanetControl = false;
            // }
        }

        if (self.showPointDetails) {
            const panelWidth = 350;
            const panelHeight = 200;
            const selectedPoint = self.clickedPoint;
            const RH = Planet.getRelativeHumidity(self.planet.getSubstanceDivider(), self.planet.temperature[selectedPoint], self.planet.waterVaporMass[selectedPoint]);

            self.showPointDetails = ui.window(vg, game, "point-details", panelWidth, panelHeight);
            defer ui.endWindow(vg);
            vg.textAlign(.{ .horizontal = .left, .vertical = .top });
            ui.label(vg, game, "Altitude: {d:.2} km", .{self.planet.elevation[selectedPoint] - self.planet.radius}, 90, 0);
            ui.label(vg, game, "Temperature: {d:.1}°C", .{self.planet.temperature[selectedPoint] - 273.15}, 90, 20);
            ui.label(vg, game, "Humidity: {d:.0}%", .{RH * 100}, 90, 40);
        }

        if (self.showEscapeMenu) {
            vg.beginPath();
            vg.fillColor(nvg.rgbaf(0, 0, 0, 0.4));
            vg.rect(0, 0, size.x(), size.y());
            vg.fill();

            const panelWidth = 200;
            const panelHeight = 300;
            const panelX = size.x() / 2 - panelWidth / 2;
            const panelY = size.y() / 2 - panelHeight / 2;

            vg.beginPath();
            vg.fillColor(nvg.rgbf(0.8, 0.8, 0.8));
            vg.rect(panelX, panelY, panelWidth, panelHeight);
            vg.fill();

            if (ui.button(vg, game, "save-game", panelX + panelWidth / 2 - 170 / 2, panelY + 10, 170, 40, "Save")) {
                self.defer_saveGame = true;
            }
            if (ui.button(vg, game, "exit-game", panelX + panelWidth / 2 - 170 / 2, panelY + 80, 170, 40, "Exit")) {
                game.setState(MainMenuState);
            }
        }

        const renderHud = !self.showEscapeMenu;
        if (renderHud) {
            // TODO: in addition to that, for tool selection use a circle that spawns under the cursor when you click right mouse
            const panelWidth = 400;
            const panelHeight = 70;
            const panelX = 10;
            const panelY = 10;

            const colorGradBottom = nvg.lerpRGBA(nvg.rgba(255, 255, 255, 100), nvg.rgba(0, 0, 0, 100), 1 - 0.2);
            vg.beginPath();
            vg.fillPaint(vg.linearGradient(panelX - 5, panelY - 5, panelX + panelWidth + 10, panelY + panelHeight + 10, nvg.rgb(255, 255, 255), colorGradBottom));
            vg.roundedRect(panelX - 5, panelY - 5, panelWidth + 10, panelHeight + 10, 10);
            vg.fill();

            if (ui.toolButton(vg, game, "no-tool", panelX, panelY, 50, 50, renderer.textureCache.get("ui/no-tool"))) {
                self.selectedTool = .None;
            }
            if (ui.toolButton(vg, game, "emit-water", panelX + 70, panelY, 50, 50, renderer.textureCache.get("ui/emit-water"))) {
                self.selectedTool = .EmitWater;
            }
            if (ui.toolButton(vg, game, "drain-water", panelX + 140, panelY, 50, 50, renderer.textureCache.get("ui/drain-water"))) {
                self.selectedTool = .DrainWater;
            }
            if (ui.toolButton(vg, game, "place-vegetation", panelX + 210, panelY, 50, 50, renderer.textureCache.get("ui/place-vegetation"))) {
                self.selectedTool = .PlaceVegetation;
            }
            if (ui.toolButton(vg, game, "raise-terrain", panelX + 280, panelY, 50, 50, renderer.textureCache.get("ui/raise-terrain"))) {
                self.selectedTool = .RaiseTerrain;
            }
            if (ui.toolButton(vg, game, "lower-terrain", panelX + 350, panelY, 50, 50, renderer.textureCache.get("ui/lower-terrain"))) {
                self.selectedTool = .LowerTerrain;
            }
            if (ui.toolButton(vg, game, "place-vegetation", panelX + 420, panelY, 50, 50, renderer.textureCache.get("ui/place-vegetation"))) {
                self.selectedTool = .PlaceLife;
            }
        }

        if (self.debug_showMoreInfo) {
            if (ui.button(vg, game, "reload-shaders", 20, 210, 170, 40, "Reload shaders")) {
                renderer.reloadShaders() catch {};
            }

            vg.textAlign(.{ .horizontal = .left, .vertical = .top });
            const baseX = size.x() - 350;
            var baseY = size.y() - 290;
            const point = self.selectedPoint;
            const planet = self.planet;

            const RH = Planet.getRelativeHumidity(planet.getSubstanceDivider(), planet.temperature[point], planet.waterVaporMass[point]);
            const meanPointArea = planet.getMeanPointArea();

            ui.label(vg, game, "Point #{d}", .{point}, baseX, baseY);
            baseY += 30;

            ui.label(vg, game, "Point Area: {d}km²", .{@floor(planet.getMeanPointArea() / 1_000_000)}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Altitude: {d:.1} km", .{planet.elevation[point] - planet.radius}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Temperature: {d:.3}°C", .{planet.temperature[point] - 273.15}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Humidity: {d:.1}%", .{RH * 100}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Water Mass: {:.1} kg", .{planet.waterMass[point] * 1_000_000_000}, baseX, baseY);
            baseY += 20;

            // The units are given in centimeters, which is the equivalent amount of water that could be produced if all the water vapor in the column were to condense
            // similar to https://earthobservatory.nasa.gov/global-maps/MYDAL2_M_SKY_WV
            ui.label(vg, game, "Water Vapor: {d:.1} cm", .{planet.waterVaporMass[point] * 1_000_000_000 / planet.getMeanPointArea() * planet.getKmPerWaterMass() * 100_000}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Vapor Mass: {d:.1} kg/m²", .{planet.waterVaporMass[point] * 1_000_000_000 / planet.getMeanPointArea()}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Vapor Pressure: {d:.0} / {d:.0} Pa", .{
                Planet.getPartialPressure(planet.getSubstanceDivider(), planet.temperature[point], planet.waterVaporMass[point]),
                Planet.getEquilibriumVaporPressure(planet.temperature[point]),
            }, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Air Speed: {d:.1} km/h", .{planet.airVelocity[point].length() * 3600}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Air Position Error: {d:.1}, {d:.1} km", .{ planet.airPositionError[point].x() * planet.radius, planet.airPositionError[point].y() * planet.radius }, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "Air Pressure: {d:.2} bar", .{planet.getAirPressureOfPoint(point) / 100_000}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "CO2 Mass: {d:.1} kg/m²", .{planet.averageCarbonDioxideMass * 1_000_000_000 / meanPointArea}, baseX, baseY);
            baseY += 20;

            ui.label(vg, game, "O2 Mass: {d:.1} kg/m²", .{planet.averageOxygenMass * 1_000_000_000 / meanPointArea}, baseX, baseY);
            baseY += 20;
        }

        if (ui.button(vg, game, "game-pause", size.x() - 70, 30, 40, 40, if (self.paused) ">" else "||")) {
            self.paused = !self.paused;
        }

        {
            vg.textAlign(.{ .horizontal = .center, .vertical = .top });
            ui.label(vg, game, "{}", .{std.fmt.fmtDuration(@as(u64, @intFromFloat(self.gameTime)) * std.time.ns_per_s)}, size.x() / 2, 10);
        }

        {
            vg.textAlign(.{ .horizontal = .center, .vertical = .top });
            ui.label(vg, game, "Game Speed", .{}, size.x() - 80, 130);
            ui.label(vg, game, "{}/s", .{std.fmt.fmtDuration(@as(u64, @intFromFloat(self.timeScale)) * std.time.ns_per_s)}, size.x() - 90, 150);
            if (ui.button(vg, game, "game-speed-minus", size.x() - 150, 150, 20, 20, "-")) {
                self.timeScale = @max(1.0, self.timeScale - 3600 * 3);
            }
            if (ui.button(vg, game, "game-speed-plus", size.x() - 25, 150, 20, 20, "+")) {
                if (self.timeScale < 190000 or true) {
                    if (self.timeScale == 1) self.timeScale = 0;
                    self.timeScale = @min(200_000_000, self.timeScale + 3600 * 3);
                }
            }
        }
    }

    pub fn saveGame(self: *PlayState) !void {
        try std.fs.cwd().makePath("saves/abc");

        const metadataFile = try std.fs.cwd().createFile("saves/abc/metadata.json", .{});
        defer metadataFile.close();
        const GameMetadata = struct {
            format_version: u32 = 0,
            game_time: f64,
            axial_tilt: f32,
            solar_constant: f32,
            planet_rotation_time: f32,
            time_scale: f32,
            radius: f32,
            subdivisions: u64,
            seed: u64,
        };
        try std.json.stringify(GameMetadata{
            .format_version = 0,
            .game_time = self.gameTime,
            .axial_tilt = self.axialTilt,
            .solar_constant = self.solarConstant,
            .planet_rotation_time = self.planetRotationTime,
            .time_scale = self.timeScale,
            .radius = self.planet.radius,
            .subdivisions = self.planet.numSubdivisions,
            .seed = self.planet.seed,
        }, .{ .whitespace = .indent_tab }, metadataFile.writer());

        const planetFile = try std.fs.cwd().createFile("saves/abc/planet.dat", .{});
        defer planetFile.close();

        var buffer = std.io.bufferedWriter(planetFile.writer());
        const writer = buffer.writer();
        const planet = self.planet;
        // planet.vertices can be re-generated using icosphere data, same for indices

        for (planet.elevation) |elevation| {
            try writer.writeInt(u32, @as(u32, @bitCast(elevation)), .little);
        }

        for (planet.temperature) |temperature| {
            try writer.writeInt(u32, @as(u32, @bitCast(temperature)), .little);
        }

        for (planet.vegetation) |vegetation| {
            try writer.writeInt(u32, @as(u32, @bitCast(vegetation)), .little);
        }

        for (planet.waterMass) |waterMass| {
            try writer.writeInt(u32, @as(u32, @bitCast(waterMass)), .little);
        }

        for (planet.waterVaporMass) |waterVaporMass| {
            try writer.writeInt(u32, @as(u32, @bitCast(waterVaporMass)), .little);
        }

        for (planet.airVelocity) |airVelocity| {
            try writer.writeInt(u32, @as(u32, @bitCast(airVelocity.x())), .little);
            try writer.writeInt(u32, @as(u32, @bitCast(airVelocity.y())), .little);
        }

        // TODO: save lifeforms

        try buffer.flush();
    }

    pub fn deinit(self: *PlayState, game: *Game) void {
        SunMesh.deinit(game.allocator);
        self.planet.deinit();
        self.framebuffer.deinit();
    }
};
