const std = @import("std");
const nvg = @import("nanovg");
const renderer = @import("renderer.zig");
const Game = @import("main.zig").Game;

const colors = struct {
    const main = nvg.rgb(255, 255, 255);
};

pub const UiComponentState = union(enum) {
    Button: struct {
        color: nvg.Color,
        pressed: bool = false,
    },
    ToolButton: struct {
        color: nvg.Color,
        pressed: bool = false,
        underlineWidth: f32 = 0,
    },
    Label: struct {
        color: nvg.Color,
    },
    Window: struct {
        x: f32,
        y: f32,
        moving: bool = false,
        moveRelX: f32 = 0,
        moveRelY: f32 = 0,
    },
};

pub fn button(vg: nvg, game: *Game, name: []const u8, x: f32, y: f32, w: f32, h: f32, text: []const u8) bool {
    var transform: [6]f32 = undefined;
    vg.currentTransform(&transform);

    var dstx: f32 = undefined;
    var dsty: f32 = undefined;
    nvg.transformPoint(&dstx, &dsty, &transform, x, y);

    const cursor = game.window.getCursorPos();
    const pressed = game.window.getMouseButton(.left) == .press;
    const hovered = cursor.xpos >= dstx and cursor.ypos >= dsty and cursor.xpos < dstx + w and cursor.ypos < dsty + h;
    var state = game.imgui_state.get(name) orelse UiComponentState{ .Button = .{ .color = colors.main } };
    defer game.imgui_state.put(name, state) catch {};

    const targetColor = if (hovered) nvg.rgb(200, 200, 200) else colors.main;
    state.Button.color = nvg.lerpRGBA(state.Button.color, targetColor, 1 - 0.2);
    const colorGradBottom = nvg.lerpRGBA(state.Button.color, nvg.rgb(0, 0, 0), 1 - 0.2);

    vg.beginPath();
    vg.fillPaint(vg.linearGradient(x, y, x, y + h, state.Button.color, colorGradBottom));
    vg.roundedRect(x, y, w, h, 10);
    vg.fill();

    vg.fontSize(20.0);
    vg.fontFace("sans-serif");
    vg.textAlign(.{ .horizontal = .center, .vertical = .middle });
    vg.fillColor(nvg.rgb(0, 0, 0));
    vg.fontBlur(if (hovered) 0 else 0.5);
    _ = vg.text(x + w / 2, y + h / 2, text);

    if (hovered) {
        if (state.Button.pressed and pressed == false) {
            state.Button.pressed = false;
            return true;
        } else {
            state.Button.pressed = pressed;
        }
    }
    return false;
}

pub fn toolButton(vg: nvg, game: *Game, name: []const u8, x: f32, y: f32, w: f32, h: f32, image: *renderer.Texture) bool {
    const cursor = game.window.getCursorPos();
    const pressed = game.window.getMouseButton(.left) == .press;
    const hovered = cursor.xpos >= x and cursor.ypos >= y and cursor.xpos < x + w and cursor.ypos < y + h + 20;
    var state = game.imgui_state.get(name) orelse UiComponentState{ .ToolButton = .{ .color = colors.main } };
    defer game.imgui_state.put(name, state) catch {};

    const targetColor = if (hovered) nvg.rgb(50, 50, 200) else nvg.rgb(100, 100, 255);
    state.ToolButton.color = nvg.lerpRGBA(state.ToolButton.color, targetColor, 1 - 0.2);

    const targetUnderlineWidth = if (hovered) w else 10;
    state.ToolButton.underlineWidth = state.ToolButton.underlineWidth * 0.8 + targetUnderlineWidth * 0.2;

    vg.beginPath();
    vg.fillPaint(vg.imagePattern(x, y, w, h, 0, image.toVgImage(vg), 1.0));
    vg.roundedRect(x, y, w, h, 10);
    vg.fill();

    vg.beginPath();
    vg.fillColor(state.ToolButton.color);
    vg.roundedRect(x + w / 2 - state.ToolButton.underlineWidth / 2, y + h + 10, state.ToolButton.underlineWidth, 10, 5);
    vg.fill();

    if (hovered) {
        if (state.ToolButton.pressed and pressed == false) {
            state.ToolButton.pressed = false;
            return true;
        } else {
            state.ToolButton.pressed = pressed;
        }
    }
    return false;
}

pub fn img(vg: nvg, x: f32, y: f32, w: f32, h: f32, image: *renderer.Texture) void {
    vg.beginPath();
    vg.fillPaint(vg.imagePattern(x, y, w, h, 0, image.toVgImage(vg), 1.0));
    vg.rect(x, y, w, h);
    vg.fill();
}

pub fn label(vg: nvg, game: *Game, comptime fmt: []const u8, args: anytype, x: f32, y: f32) void {
    _ = game;
    var buf: [500]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;

    vg.fontSize(20.0);
    vg.fontFace("sans-serif");
    vg.fillColor(nvg.rgb(255, 255, 255));
    vg.fontBlur(0);
    _ = vg.text(x, y, text);
}

pub fn shadow(vg: nvg, x: f32, y: f32, w: f32, h: f32) void {
    vg.beginPath();
    vg.fillColor(nvg.rgbaf(0, 0, 0, 0.20));
    vg.roundedRect(x + 4, y + 4, w, h, 8);
    vg.fill();

    vg.beginPath();
    vg.fillColor(nvg.rgbaf(0, 0, 0, 0.19));
    vg.roundedRect(x + 6, y + 6, w, h, 20);
    vg.fill();
}

/// Returns true when window is staying opened
/// Returns false when window closed.
pub fn window(vg: nvg, game: *Game, name: []const u8, w: f32, h: f32) bool {
    // TODO: place window in the middle of the screen or in a position defined in arguments
    var state = game.imgui_state.get(name) orelse UiComponentState{ .Window = .{ .x = 100, .y = 100 } };
    defer game.imgui_state.put(name, state) catch {};
    const cursor = game.window.getCursorPos();
    const pressed = game.window.getMouseButton(.left) == .press;
    const titleBarHeight = 30;
    const hovered = cursor.xpos >= state.Window.x and cursor.ypos >= state.Window.y and
        cursor.xpos < state.Window.x + w and cursor.ypos < state.Window.y + titleBarHeight;

    if (pressed and hovered and !state.Window.moving) {
        state.Window.moving = true;
        state.Window.moveRelX = @floatCast(f32, cursor.xpos) - state.Window.x;
        state.Window.moveRelY = @floatCast(f32, cursor.ypos) - state.Window.y;
    } else if (!pressed) {
        state.Window.moving = false;
    }

    if (state.Window.moving) {
        state.Window.x = @floatCast(f32, cursor.xpos) - state.Window.moveRelX;
        state.Window.y = @floatCast(f32, cursor.ypos) - state.Window.moveRelY;
    }

    shadow(vg, state.Window.x, state.Window.y, w, h);
    vg.beginPath();
    vg.fillColor(nvg.rgbaf(0.8, 0.8, 0.8, 0.8));
    vg.roundedRect(state.Window.x, state.Window.y, w, h, 10);
    vg.fill();

    vg.beginPath();
    vg.fillColor(nvg.rgbaf(0.5, 0.5, 1.0, 1.0));
    vg.rect(state.Window.x, state.Window.y, w, titleBarHeight);
    vg.fill();

    vg.save();
    vg.translate(state.Window.x, state.Window.y + titleBarHeight + 4);

    return true;
}

pub fn endWindow(vg: nvg) void {
    vg.restore();
}

/// Returns true if hovered
pub fn coloredLabel(vg: nvg, game: *Game, name: []const u8, comptime fmt: []const u8, args: anytype, x: f32, y: f32, color: nvg.Color) bool {
    const cursor = game.window.getCursorPos();
    // TODO: real text size
    var buf: [500]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;

    // This will be filled as [xMin, yMin, xMax, yMax]
    var bounds: [4]f32 = undefined;
    vg.fontFace("sans-serif");
    vg.fontBlur(0);
    _ = vg.textBounds(x, y, text, &bounds);

    const hovered = cursor.xpos >= bounds[0] and cursor.ypos >= bounds[1] and cursor.xpos < bounds[2] and cursor.ypos < bounds[3];
    var state = game.imgui_state.get(name) orelse UiComponentState{ .Label = .{ .color = color } };
    defer game.imgui_state.put(name, state) catch {};

    const targetColor = color;
    state.Label.color = nvg.lerpRGBA(state.Label.color, targetColor, 1 - 0.2);

    vg.fillColor(state.Label.color);
    _ = vg.text(x, y, text);

    return hovered;
}
