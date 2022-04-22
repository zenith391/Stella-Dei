#version 330 core

uniform vec3 lightColor;
uniform vec3 lightDir;

in vec3 normal;

out vec4 fragColor;

void main() {
	vec3 ambient = 0.15 * lightColor;
	vec3 diffuse = max(dot(normal, lightDir), 0.0) * lightColor;
	vec3 objectColor = vec3(1.0f, 1.0f, 1.0f);

	vec3 result = (ambient + diffuse) * objectColor;
	fragColor = vec4(result, 1.0f);
}
