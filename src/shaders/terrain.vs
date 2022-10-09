#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in float extraData;
layout (location = 3) in float aWaterElevation;
layout (location = 4) in float aVegetation;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;
uniform int selectedVertex;
uniform vec3 lightDir;
uniform float planetRadius;

out vec3 worldPosition;
out vec3 worldNormal;
out float interpData;
out float waterElevation;
out float vegetation;
out float outSelected;

out vec3 tangentViewPos;
out vec3 tangentFragPos;

void main() {
	gl_Position = projMatrix * viewMatrix * modelMatrix * vec4(aPos, 1);
	outSelected = float(selectedVertex == gl_VertexID);
	worldNormal = mat3(modelMatrix) * aNormal;
	worldPosition = vec3(modelMatrix * vec4(aPos, 1.0));
	interpData = extraData;
	vegetation = aVegetation;
	waterElevation = aWaterElevation;

	//vec3 T = normalize(cross(worldNormal, vec3(0.0, 0.0, -1.0)));
	//vec3 B = normalize(cross(worldNormal, T));
	vec3 T = vec3(0.0, 0.0, 1.0);
	vec3 B = vec3(1.0, 0.0, 0.0);
	vec3 N = normalize(worldNormal);
	mat3 TBN = transpose(mat3(T, B, N));

	tangentViewPos = TBN * -lightDir;
	tangentFragPos = TBN * worldPosition;
}
