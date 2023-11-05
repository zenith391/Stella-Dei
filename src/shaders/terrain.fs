#version 330 core

uniform vec3 lightColor;
uniform vec3 lightDir;
uniform float lightIntensity;
uniform vec3 viewPos;
uniform int displayMode;
uniform float planetRadius;
uniform float kmPerWaterMass;
uniform samplerCube noiseCubemap;
uniform sampler2D terrainNormalMap;
uniform sampler2D waterNormalMap;
uniform vec3 selectedVertexPos;
uniform vec3 vegetationColor;

in vec3 worldNormal;
in vec3 worldPosition;
in float interpData;
in float waterElevation;
in float vegetation;
in float outSelected;
in vec3 tangentViewPos;
in vec3 tangentFragPos;

out vec4 fragColor;

// Return a single noise value from 0 to 1 computed from data that stays the same frame to frame
float noiseValue() {
	return texture(noiseCubemap, worldPosition / planetRadius).x;
}

float getDepth(vec2 coords) {
	return texture(terrainNormalMap, coords).x;
}

vec2 parallaxMapping(vec2 texCoords, vec3 viewDir) {
	float heightScale = 100.0;
	float height = 1 - getDepth(texCoords);
	vec2 p = viewDir.xy / viewDir.z * (height * heightScale);
	return texCoords - p;
}

// Whiteout blend from https://bgolus.medium.com/normal-mapping-for-a-triplanar-shader-10bf39dca05a
vec3 getNormal(vec3 viewDir) {
	float waterBlend = 1 - exp(-waterElevation * 1.0);

	float scale = 0.003;
	float strength = 0.8;
	vec2 uvX = parallaxMapping(worldPosition.zy * scale, viewDir);
	vec2 uvY = parallaxMapping(worldPosition.xz * scale, viewDir);
	vec2 uvZ = parallaxMapping(worldPosition.xy * scale, viewDir);

	vec3 normalX = mix(texture(terrainNormalMap, uvX).xyz, texture(waterNormalMap, uvX).xyz, waterBlend);
	vec3 normalY = mix(texture(terrainNormalMap, uvY).xyz, texture(waterNormalMap, uvY).xyz, waterBlend);
	vec3 normalZ = mix(texture(terrainNormalMap, uvZ).xyz, texture(waterNormalMap, uvZ).xyz, waterBlend);

	normalX = vec3(normalX.xy + worldNormal.zy, abs(normalX.z) * worldNormal.x);
	normalY = vec3(normalY.xy + worldNormal.xz, abs(normalY.z) * worldNormal.y);
	normalZ = vec3(normalZ.xy + worldNormal.xy, abs(normalZ.z) * worldNormal.z);

	vec3 blend = normalize(abs(worldNormal));

	return mix(worldNormal, normalize(
		normalX.zyx * blend.x + normalY.xzy * blend.y + normalZ.xyz * blend.z
	), strength);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


void main() {
	if (displayMode == 0) {
		vec3 ambient = (0.05 + lightIntensity / 10) * lightColor;

		vec3 nViewDir = normalize(tangentViewPos - tangentFragPos);
		vec3 nNormal = getNormal(nViewDir);
		// TODO: texture coords
		
		vec3 diffuse = max(dot(nNormal, lightDir) * lightIntensity, 0.0) * lightColor;

		float specularStrength = 0.1;
		float specularPower = 64;
		vec3 terrainColor = mix(vec3(0.5f, 0.4f, 0.3f), vegetationColor, vegetation);
		vec3 objectColor = terrainColor * (noiseValue() / 20 + 1);

		float waterTreshold = 0.1 + (noiseValue() * 2 - 1) * 0.025;
		if (interpData < 280.15) {
			waterTreshold = 0.0002 + (noiseValue() * 2 - 1) * 0.0001;
		}
		
		// totalElevation = elevation + water (km)
		// partialWaterElevation = water (km)
		float partialWaterElevation = waterElevation * 10;
		if (partialWaterElevation >= waterTreshold) {
			float depthMultiplier = 0.2;
			float alphaMultiplier = 1.0;

			float opticalDepth = 1 - exp(-partialWaterElevation * depthMultiplier);
			float alpha = 1 - exp(-partialWaterElevation * alphaMultiplier);

			// vec3 waterColor = mix(vec3(0.1f, 0.3f, 0.8f), vec3(0.05f, 0.2f, 0.4f), min(opticalDepth, 1)); // ocean blue
			// objectColor = mix(objectColor, waterColor, alpha);

			float iceLevel = min(1, exp((-interpData + 272.15) / 5));
			objectColor = mix(objectColor, vec3(1.0f, 1.0f, 1.0f), iceLevel * min(1, alpha*10));
			if (interpData > 273.15) {
				specularPower = mix(16, 256, min(partialWaterElevation*1*(1-iceLevel), 1));
				specularStrength = 0.5;
			} else {
				specularPower = 64;
				specularStrength = 0.5;
			}
		}

		vec3 viewDir = normalize(viewPos - worldPosition);
		vec3 reflectDir = reflect(-lightDir, nNormal);
		float spec = pow(max(dot(viewDir, reflectDir), 0.0), specularPower);
		vec3 specular = specularStrength * spec * lightColor * lightIntensity;

		vec3 result = (ambient + diffuse + specular) * objectColor;
		float selected = 1 - length(worldPosition - selectedVertexPos) / 100;
		if (selected > 0) {
			float selectedE = 1 - (1 - selected) * (1 - selected);
			result = mix(result, vec3(0.1f, 0.1f, 0.9f), selectedE);
		}
		fragColor = vec4(result, 1.0f);
	} else if (displayMode == 1) { // temperature
		vec3 cold = vec3(234.0f / 360.0f, 1.0f, 0.5f);
		vec3 hot  = vec3(  0.0f / 360.0f, 1.0f, 0.33f);
		// Default range of -50°C - 50°C
		vec3 result = hsv2rgb(mix(cold, hot, clamp((interpData - 273.15 + 50) / 100, 0, 1)));
		fragColor = vec4(result, 1.0f);
	} else if (displayMode == 2) { // water vapor
		vec3 cold = vec3(0.0f, 0.0f, 0.0f);
		vec3 hot  = vec3(1.0f, 1.0f, 0.0f);
		float waterKm = interpData * kmPerWaterMass;
		vec3 result = mix(cold, hot, (waterKm) / 0.001);
		fragColor = vec4(result, 1.0f);
	} else if (displayMode == 3) { // wind
		// From 0 to 200 km/h
		float right = interpData * 3600.0 / 200.0;
		float up = waterElevation * 3600.0 / 200.0;
		vec3 result = vec3(right / 2, sqrt(right * right + up * up), up / 2);
		fragColor = vec4(result, 1.0f);
	} else if (displayMode == 4) { // rainfall
		// for rainfall, colors are in HSV (in order to make a smooth color gradient)
		vec3 cold = vec3( 25.0f / 360.0f, 1.0f, 0.33f);
		vec3 hot  = vec3(234.0f / 360.0f, 1.0f, 0.5f);
		float waterKm = interpData * kmPerWaterMass;
		vec3 result = hsv2rgb(mix(cold, hot, clamp((waterKm) / 0.03, 0, 1)));
		fragColor = vec4(result, 1.0f);
	}
}

