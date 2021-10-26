#version 330 core
layout (location = 0) in vec2 aPos;

uniform vec2 offset;
uniform vec2 scale;

void main() {
	vec2 position = aPos;

	// Apply scaling
	position *= scale;

	// Apply translation
	position += offset;

	// Invert Y position
	position.y = -position.y;

	gl_Position = vec4(position.x, position.y, 0, 1);
}
