#version 330 core
layout (location = 0) in vec2 aPos;

uniform vec2 offset;

void main() {
	vec2 position = aPos + offset;
	gl_Position = vec4(position.x, position.y, 0, 1);
}
