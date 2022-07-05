#version 330 core

uniform vec3 lightColor;
uniform vec3 lightDir;
uniform float lightIntensity;
uniform float kmPerWaterMass;

in vec3 normal;
in float cloudLevel;

out vec4 fragColor;

void main() {
	vec3 ambient = (0.05 + lightIntensity / 50) * lightColor;
	vec3 diffuse = max(dot(normal, lightDir) * lightIntensity, 0.0) * lightColor;

	float alpha =  1 - pow(2.0, -cloudLevel * kmPerWaterMass * 1000);
	vec3 objectColor = vec3(1.0f, 1.0f, 1.0f);
	vec4 result = vec4((ambient + diffuse) * objectColor, clamp(alpha, 0.0, 1.0));
	fragColor = result;
}
