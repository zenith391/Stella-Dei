#version 330 core

uniform vec3 lightColor;
uniform vec3 lightDir;
uniform vec3 viewPos;
uniform int displayMode;
uniform float planetRadius;
uniform samplerCube noiseCubemap;

in vec3 normal;
in vec3 localPosition;
in float interpData;
in float waterElevation;
in float vegetation;
in float outSelected;

out vec4 fragColor;

// Return a single noise value from 0 to 1 computed from data that stays the same frame to frame
float noiseValue() {
	return texture(noiseCubemap, localPosition / planetRadius).x;
}

void main() {
	if (displayMode == 0) {
		vec3 ambient = 0.15 * lightColor;
		
		vec3 diffuse = max(dot(normal, lightDir), 0.0) * lightColor;

		float specularStrength = 0.2;
		float specularPower = 32;
		vec3 terrainColor = mix(vec3(0.5f, 0.4f, 0.3f), vec3(0.0f, 1.0f, 0.0f), vegetation);
		vec3 objectColor = terrainColor * (noiseValue() / 20 + 1);

		float waterTreshold = 0.1 + (noiseValue() * 2 - 1) * 0.025;
		if (waterElevation >= waterTreshold) {
			if (interpData < 273.15) {
				objectColor = vec3(1.0f, 1.0f, 1.0f);
			} else {
				objectColor = mix(vec3(0.1f, 0.3f, 0.8f), vec3(0.05f, 0.2f, 0.4f), min(waterElevation*0.15, 1)); // ocean blue
				specularPower = mix(16, 256, min(waterElevation*1, 1));
				specularStrength = 0.5;
			}
		}

		vec3 viewDir = normalize(viewPos - localPosition);
		vec3 reflectDir = reflect(-lightDir, normal);
		float spec = pow(max(dot(viewDir, reflectDir), 0.0), specularPower);
		vec3 specular = specularStrength * spec * lightColor;

		vec3 result = (ambient + diffuse + specular) * objectColor;
		if (outSelected > 0) {
			result = mix(result, vec3(0.1f, 0.1f, 0.9f), outSelected / 2);
		}
		fragColor = vec4(result, 1.0f);
	} else if (displayMode == 1) {
		vec3 cold = vec3(0.0f, 0.0f, 1.0f);
		vec3 hot  = vec3(1.0f, 0.0f, 0.0f);
		// Default range of 200°K - 400°K (around -80°C - 120°C)
		vec3 result = mix(cold, hot, (interpData - 200) / 200);
		fragColor = vec4(result, 1.0f);
	}
}
