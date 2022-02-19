#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec4 aColor;

uniform mat4 projMatrix;

out vec2 texCoord;
out vec4 vertexColor;

void main() {
	gl_Position = projMatrix * vec4(aPos, 0, 1);
	texCoord = aTexCoord;
	vertexColor = aColor;
}
