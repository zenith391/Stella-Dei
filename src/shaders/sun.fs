#version 330 core

in vec3 normal;

out vec4 fragColor;

void main() {
	// TODO: base on the sun's temperature?
	vec3 objectColor = vec3(10.0f, 9.0f, 8.0f);
	vec3 result = objectColor;
	
	fragColor = vec4(result, 1.0f);
}
