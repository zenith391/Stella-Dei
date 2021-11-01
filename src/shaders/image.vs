#version 330 core
layout (location = 0) in vec2 aPos;

out vec2 texCoord;

uniform mat4 projMatrix;
uniform mat4 modelMatrix;

void main() {
	gl_Position = projMatrix * modelMatrix * vec4(aPos, 0, 1);
	texCoord = aPos + vec2(0.5f, 0.5f);
}
