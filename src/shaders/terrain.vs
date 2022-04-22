#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in float extraData;
layout (location = 3) in float aWaterElevation;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;
uniform int selectedVertex;

out vec3 localPosition;
out vec3 normal;
out float interpData;
out float waterElevation;
out float outSelected;

void main() {
	gl_Position = projMatrix * viewMatrix * modelMatrix * vec4(aPos, 1);
	outSelected = float(selectedVertex == gl_VertexID);
	normal = aNormal;
	localPosition = vec3(modelMatrix * vec4(aPos, 1.0));
	interpData = extraData;
	waterElevation = aWaterElevation;
}
