#version 330 core

uniform vec3 lightColor;
uniform vec3 lightDir;
uniform vec3 viewPos;
uniform int displayMode;
uniform float planetRadius;
uniform samplerCube noiseCubemap;

in vec3 localPosition;
in float interpData;
in float waterElevation;

out vec4 fragColor;

// Return a single noise value from 0 to 1 computed from data that stays the same frame to frame
float noiseValue() {
	return texture(noiseCubemap, localPosition / planetRadius).x;
}

void main() {
	if (displayMode == 0) {
		vec3 ambient = 0.15 * lightColor;

		// TODO: account for terrain variations to greatly improve looks
		vec3 normal = normalize(localPosition);
		
		vec3 diffuse = max(dot(normal, lightDir), 0.0) * lightColor;

		float lengthDeviation = length(localPosition) / planetRadius - 1;
		float specularStrength = 0.2;
		float specularPower = 32;
		vec3 objectColor = vec3(0.5f, 0.4f, 0.3f) * (lengthDeviation / 4 + 1);

		float waterTreshold = 0.001 + (noiseValue() * 2 - 1) * 0.00025;
		if (waterElevation >= waterTreshold && interpData < 373.15) {
			if (interpData < 273.15) {
				objectColor = vec3(1.0f, 1.0f, 1.0f);
				//objectColor = mix(objectColor, vec3(1.0f, 1.0f, 1.0f), min(waterElevation*1000, 1)); // ice
			} else {
				objectColor = mix(vec3(0.1f, 0.3f, 0.8f), vec3(0.05f, 0.2f, 0.4f), min(waterElevation*15, 1)); // ocean blue
				specularPower = mix(16, 256, min(waterElevation*100, 1));
				specularStrength = 0.5;
			}
		}

		vec3 viewDir = normalize(viewPos - localPosition);
		vec3 reflectDir = reflect(-lightDir, normal);
		float spec = pow(max(dot(viewDir, reflectDir), 0.0), specularPower);
		vec3 specular = specularStrength * spec * lightColor;

		vec3 result = (ambient + diffuse + specular) * objectColor;
		fragColor = vec4(result, 1.0f);
	} else if (displayMode == 1) {
		vec3 cold = vec3(0.0f, 0.0f, 1.0f);
		vec3 hot  = vec3(1.0f, 0.0f, 0.0f);
		// Default range of 200°K - 400°K (around -80°C - 120°C)
		vec3 result = mix(cold, hot, (interpData - 200) / 200);
		fragColor = vec4(result, 1.0f);
	}
}
