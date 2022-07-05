#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in float aCloudLevel;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

out vec3 normal;
out float cloudLevel;

void main() {
	gl_Position = projMatrix * viewMatrix * modelMatrix * vec4(aPos, 1);
	normal = normalize(aPos);
	cloudLevel = aCloudLevel;
}
