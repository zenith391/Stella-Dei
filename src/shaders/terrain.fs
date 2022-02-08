#version 330 core

uniform vec3 lightColor;

out vec4 fragColor;

void main() {
	vec3 ambient = 0.5 * lightColor;

	vec3 objectColor = vec3(0.2f, 1.0f, 0.2f);
	vec3 result = ambient * objectColor;
	fragColor = vec4(result, 1.0f);
}
