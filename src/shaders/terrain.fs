#version 330 core

uniform vec3 lightColor;

in vec3 worldPosition;
in vec3 localPosition;

out vec4 fragColor;

void main() {
	vec3 ambient = 0.15 * lightColor;
	vec3 lightPos = vec3(10, 10, 10);

	// This doesn't account for terrain variations
	vec3 normal = normalize(localPosition);
	
	vec3 lightDir = normalize(lightPos - worldPosition);
	vec3 diffuse = max(dot(normal, lightDir), 0.0) * lightColor;

	float lengthDeviation = length(localPosition) - 1;
	vec3 objectColor = vec3(0.2f, 1.0f, 0.2f) * (lengthDeviation * 5 + 1);
	if (lengthDeviation < 0) {
		objectColor = vec3(0.1f, 0.3f, 0.8f); // ocean blue
	}
	vec3 result = (ambient + diffuse) * objectColor;
	fragColor = vec4(result, 1.0f);
}
