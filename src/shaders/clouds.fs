#version 330 core

uniform vec3 lightColor;
uniform vec3 lightDir;
uniform float lightIntensity;
uniform float kmPerWaterMass;
uniform float gameTime;
uniform sampler2D waterNormalMap;

in vec3 normal;
in float waterElevation;
in vec3 worldPosition;

out vec4 fragColor;

void main() {
	vec3 pPrime = vec3(normal.x, 0, normal.z);
	vec2 tangent = vec2(-pPrime.y, pPrime.x);
	vec3 tangentVec3 = vec3(tangent.x, normal.y, tangent.y);
	vec3 bitangent = cross(tangentVec3, normal);

	vec2 mapPosition = vec2(worldPosition.x/100 + gameTime/100000, worldPosition.y/100 - gameTime/100000);
	vec3 map = normalize(texture(waterNormalMap, mapPosition).xyz);
	vec3 newNormal = normalize(map.x * tangentVec3 + map.y * bitangent + map.z * normal);

	vec3 ambient = (0.05 + lightIntensity / 50) * lightColor;
	vec3 diffuse = max(dot(newNormal, lightDir) * lightIntensity, 0.0) * lightColor;

	float alpha =  clamp(1 - exp(-waterElevation * 4), 0.0, 1.0);
	// TODO: use actual depth value as it's more precise?
	vec3 shallow = vec3(0.5, 0.5, 0.9);
	vec3 deep = vec3(0.1, 0.1, 0.6);
	vec3 objectColor = mix(shallow, deep, alpha);

	vec4 result = vec4((ambient + diffuse) * objectColor, alpha);
	// vec4 result = vec4(newNormal, 1.0);

	fragColor = result;
}
