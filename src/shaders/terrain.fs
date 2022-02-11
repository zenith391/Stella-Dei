#version 330 core

uniform vec3 lightColor;
uniform int displayMode;

in vec3 worldPosition;
in vec3 localPosition;
in float interpData;

out vec4 fragColor;

void main() {
	if (displayMode == 0) {
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
	} else if (displayMode == 1) {
		vec3 cold = vec3(0.0f, 0.0f, 1.0f);
		vec3 hot  = vec3(1.0f, 0.0f, 0.0f);
		// Default range of 200°K - 400°K (around -80°C - 120°C)
		vec3 result = mix(cold, hot, (interpData - 200) / 200);
		fragColor = vec4(result, 1.0f);
	}
}
