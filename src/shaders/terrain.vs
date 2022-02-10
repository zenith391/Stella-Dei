#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

out vec3 worldPosition;
out vec3 localPosition;

void main() {
	gl_Position = projMatrix * viewMatrix * modelMatrix * vec4(aPos, 1);
	worldPosition = vec3(modelMatrix * vec4(aPos, 1));
	localPosition = aPos;
}
