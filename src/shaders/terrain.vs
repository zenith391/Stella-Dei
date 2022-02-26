#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in float extraData;
layout (location = 2) in float aWaterElevation;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

out vec3 localPosition;
out float interpData;
out float waterElevation;

void main() {
	gl_Position = projMatrix * viewMatrix * modelMatrix * vec4(aPos, 1);
	localPosition = aPos;
	interpData = extraData;
	waterElevation = aWaterElevation;
}
